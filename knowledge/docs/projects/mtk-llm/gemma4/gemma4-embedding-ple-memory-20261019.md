# Gemma4 E2B-it embedding 与 PLE 内存估算（2026-10-19）

## 结论

Gemma4 E2B-it 的 PLE 查找表远大于普通 token embedding。FP16 下，两张外部 LUT 合计 **5.125 GiB**；当前 MTK 设备模板使用 FP16，因此该值是设备运行时需要考虑的查表文件规模。两张表若都使用 INT8，原始 LUT 理论上可降到 **2.5625 GiB**；若都紧密打包为 INT4，理论大小为 **1.28125 GiB**。INT8 尚未通过设备端验证，INT4 是纯容量估算，尚未验证量化质量、bin 格式或设备运行时支持。

## 参数与文件大小

模型参数：`vocab_size=262144`、`hidden_size=1536`、`num_hidden_layers=35`、`d_per_layer_input=256`。文件大小按每个元素 FP16=2 B、INT8=1 B 计算，十进制 GB 与二进制 GiB 分列说明。

| 表 | 形状 | 参数量 | FP16 | INT8 | INT4 紧密打包估算 |
|---|---:|---:|---:|---:|---:|
| Token embedding | 262144 × 1536 | 402,653,184 | 805,306,368 B = 805.3 MB = 768 MiB | 402,653,184 B = 402.7 MB = 384 MiB | 201,326,592 B = 201.3 MB = 192 MiB |
| Per-layer embedding (PLE) | 262144 × 35 × 256 | 2,348,810,240 | 4,697,620,480 B = 4.698 GB = 4.375 GiB | 2,348,810,240 B = 2.349 GB = 2.1875 GiB | 1,174,405,120 B = 1.174 GB = 1.09375 GiB |
| 合计 | — | 2,751,463,424 | 5,502,926,848 B = 5.503 GB = 5.125 GiB | 2,751,463,424 B = 2.751 GB = 2.5625 GiB | 1,375,731,712 B = 1.376 GB = 1.28125 GiB |

每层 PLE 有 262144 × 256 = 67,108,864 个元素，即 FP16 128 MiB、INT8 64 MiB 或 INT4 紧密打包 32 MiB。PLE 表是普通 embedding 的约 5.83 倍。INT4 大小假设两个 4-bit 值共用一个字节，不包括 scale、zero point、分组元数据、对齐或文件头；实际量化文件可能更大。SDK 导出的 FP16 embedding/PLE 分别预乘 `sqrt(1536)` 和 `sqrt(256)=16`；缩放改变数值，不改变参数量或文件大小。

普通 embedding 配置为 tied word embeddings，因此参数统计中不重复计入 lm_head。但 MTK 部署另有 embedding LUT 文件，输出头权重仍可能包含在 DLA/共享权重中；上表不含输出头模型文件、KV cache 或 DLA 工作区。

## 运行时内存

项目 v2 设备模板的 `modelInputType` 是 FP16，打包脚本按 `262144 × 1536 × 2` 和 `262144 × 35 × 256 × 2` 检查 FP16 文件。检查过的 llm_cmdline_tool 通过 `mmap(MAP_SHARED)` 映射 LUT，并在初始化时逐页预取。因此 LUT 可带来约 5.125 GiB 的文件映射和文件页缓存占用；这些是文件支持的页面，不是额外的私有堆复制，系统在内存压力下可以回收页缓存。

按 prompt 形状 `t=256` 估算 FP16 输入缓冲区：

- Token embedding `[1,256,1536]`：786,432 B = 0.75 MiB。
- PLE `[1,256,35,256]`：4,587,520 B = 4.375 MiB。
- 合计约 5.125 MiB；单 token 生成时合计约 20.5 KiB/token。

以上是 FP16 查表 LUT 与对应输入缓冲区，不是模型总峰值内存。总峰值还取决于 DLA 权重/工作区、KV cache、运行时以及系统页缓存回收情况。INT4 的 1.28125 GiB 是磁盘/映射源数据的紧密打包估算；若 runtime 在查表时将 INT4 解包为 FP16，相关工作集可能高于该值。接近 INT4 原始大小的 RAM 占用需要运行时直接处理 packed INT4，或采用受控的按需解包；当前配置与文件格式未验证这条路径。

## INT4/INT8 外部 LUT 的实际情况

`embeddings`/`tail` 的 `sym4W_sym16A` 主要作用于 PTQ 图中的权重和激活路径；Embedding 与 PLE 在部署时是独立的 token-id 查表接口，不是普通 MatMul 权重。当前 NP8 runtime 没有已验证的 packed INT4 文件类型或 INT4 查表/解包路径，因此配置写成 `sym4W_sym16A` 不会自动把外部表压成两个 4-bit 值一个字节。

本次 `embedding_int16.bin`/`ple_int16.bin` 的大小分别为 805,306,368 B 和 4,697,620,480 B，与两字节/元素的原始表大小一致；它们不是 packed INT4 文件。INT16 表示运行时查表输出/模型输入接口的数据格式，不能证明外部表已按 INT4 存储。

已验证的 INT8 路径是每个 LUT 元素存一个有符号字节，runtime 读取后转换或符号扩展到模型所需的 INT16 输入格式，并通过 `embeddingFileType: INT8` 选择该路径。若要实现 INT4，需要同时增加 packed LUT 导出、scale/group 元数据和 runtime 按 token 解包转换，不能只修改 JSON 或文件名。

## INT8 状态与限制

仓库中有 embedding/PLE INT8 bin，大小符合一字节/元素。但当前 v2 打包路径优先选择 FP16 bin，设备模板仍设置 FP16；检查过的 runtime LUT 转换只允许相同类型或 FP16 文件转 FP32，不能把 INT8 bin 直接换进当前 FP16 配置。INT4 此处仅按每参数半字节计算，没有确认 SDK 能导出对应外部 LUT，也没有确认设备端支持 packed INT4 查表。

Dynamic quant + embedding INT8 的 x86 screen 结果为 6/6 OK；INT8 资产已另行完成 NP8/MDLA 及设备端 `rc=0` 验证。W4A16 + embedding INT8 + tail W8A16 变体的 x86 screen 则失败。INT4 仍需要单独验证量化精度、资产导出、runtime 解包/查表和设备兼容性。

## 项目内依据

- 模型维度、tied embedding 和 PLE 形状：`docs/toolchain_versions.md` §9.3。
- FP16 LUT 尺寸与部署打包路径：`scripts/deploy/gemma4_v2/6_package_assets.sh`。
- FP16 运行配置：`configs/gemma4/gemma4_e2b_it_device_v2.yaml.tmpl`。
- mmap、预取和 LUT 类型转换：`third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_mem_mapper.cpp`、`third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_helper/token_embedding.cpp`。
- INT8 精度状态：[Embedding INT8 PTQ](gemma4-embedding-int8-quant-2048-result-20261015.md)、[W4A16 + Embedding INT8 + tail W8A16](gemma4-w4a16-embint8-tailw8a16-result-20261015.md)。
