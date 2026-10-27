# Gemma4 Embedding/PLE INT4 存储与 Runtime 设计

本文保留 2026-10-20 至 10-21 的设计与实验过程；当前 G4LUTI4 文件和 Runtime
解码契约见 [G4LUTI4 格式说明](gemma4-external-lut-g4luti4-int4.md)。

## 基线冻结（2026-10-21）

INT4 功能开发明确基于已通过 x86 精度验证的 2026-10-15 `embedding INT8` 实验：以同一份 PTQ 产出的 `embedding_int8.bin` 和 `ple_int8.bin` 为控制基线，在相同模型、词表、PLE 形状、graph input scale 和 INT16 图输入语义下，生成 packed INT4 文件并比较数值误差。INT8 路径保持可回退，不以 2026-10-19 手机侧乱码实验作为精度基线。

已确认该 x86 实验使用完整词表 `262144`；保留的同源 FP16 LUT 为
`work/gemma4_e2b_it/gemma-4-E2B-it/embedding_fp16.bin` 和 `ple_fp16.bin`。
SDK 的 INT8 导出使用全局 `absmax / 127`，不是逐行 scale；源文件扫描得到 embedding
全局 absmax `0.55859375`、scale `0.0043983759842519685`，PLE 全局 absmax `1.125`、
scale `0.008858267716535433`。当前 G4LUTI4 的逐行 `absmax / 7` 应标为独立 INT4
策略，不能宣称与历史 INT8 使用同一量化规则；严格对照时应支持全局 scale 模式。

2026-10-21 已从同源完整词表 FP16 embedding 生成 global-scale G4LUTI4 候选：文件
大小 `202,375,264 B`、INT16 饱和率 `0`，但全量平均 RMSE 为
`0.02186942936061775`，抽样 cosine 约 `0.72–0.85`。因此格式通过而质量仍需
per-row 对照，尚未进入 x86 推理。

同源 per-row 候选随后生成，平均 RMSE `0.00518862416759521`、最大绝对误差
`0.039794921875`、INT16 饱和率 `0`，抽样 cosine `0.846–0.988`，离线数值优于
global-scale。当前暂选 per-row 作为 embedding INT4 候选，仍不能替代 x86 ROUGE-L
和 PLE INT4→FP32 验证。

## 验证顺序冻结（2026-10-21）

先验证 `embedding INT4 + PLE FP32/FP16`，再验证 `embedding INT4 + PLE INT4→FP32`。
原因是前者只改变 embedding，可以隔离 embedding INT4 的 ROUGE-L 损失；后者同时
改变 PLE 存储和 Runtime 解包，必须在前者通过后才有可解释性。当前 YAML 的
`embeddingFileType` 同时作用于 embedding 和 PLE，因此第一阶段先增加独立的
`pleFileType`/等价 Runtime 配置，让 embedding 使用 INT4、PLE 保持 FP16/FP32；
这一步不实现 PLE INT4→FP32。第一阶段 x86 ROUGE-L 通过后，再实现 PLE INT4→FP32
并进行第二阶段对比。

混合 LUT 类型配置已按最小兼容方案加入 Runtime：`pleFileType` 控制 PLE 文件类型，
`pleInputType` 控制 PLE 图输入类型；两者为 `INVALID` 时保持旧的
`embeddingFileType/modelInputType` 回退行为。第一阶段配置为：

```yaml
modelInputType: INT16
embeddingFileType: INT4
pleFileType: FP16
pleInputType: FP32
```

Embedding 与 PLE 都使用 G4LUTI4、但 PLE 解包为 FP32 时，设备 YAML 应显式设置：

```yaml
modelInputType: INT16
embeddingFileType: INT4
pleFileType: INT4
pleInputType: FP32
```

只设置 `embeddingFileType: INT4` 会令 PLE 文件类型默认继承为 INT4、PLE 图输入类型默认
继承为 INT16；这与 `ple_int4.bin` 的 G4LUTI4 `output_type=FP32` 不匹配。资产打包模板
需要能独立渲染 `pleFileType` 和 `pleInputType`。

2026-10-21 使用 NDK r29 对新增混合 LUT 配置完成完整 Android 构建，
`libmtk_llm.so` 和 `main` 编译通过；当前环境的 adb stub 跳过了设备 push，
因此仍未完成手机验证。

随后实现并验证 `group_size=128`：每行 12 个 scale，文件大小 `213,909,600 B`，
平均 RMSE `0.003901221912433684`，最大绝对误差 `0.039794921875`，INT16 饱和率
`0`，抽样 cosine `0.959–0.993`。当前 embedding 离线结果以 group128 最优，
但仍需 x86 ROUGE-L 和设备验证。

group64 对照平均 RMSE `0.0035168772520200627`，相比 group128 的
`0.003901221912433684` 降低约 `9.85%`，INT16 饱和率为 `0`；文件增加约 `12.6 MB`。
在 x86 ROUGE-L 验证前，暂不冻结最终 group size。

### Embedding INT4 离线损失对比

| 方案 | group size | groups/row | 文件大小 | RMSE | 最大绝对误差 | 抽样 cosine | INT16 饱和率 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Global | 1536 | 1 | 202,375,264 B | 0.02186943 | 0.03989956 | 0.72–0.85 | 0 |
| Per-row | 1536 | 1 | 202,375,264 B | 0.00518862 | 0.03979492 | 0.846–0.988 | 0 |
| Group128 | 128 | 12 | 213,909,600 B | 0.00390122 | 0.03979492 | 0.959–0.993 | 0 |
| Group64 | 64 | 24 | 226,492,512 B | **0.00351688** | **0.03881836** | **0.977–0.994** | 0 |

以上均来自同一份完整词表 FP16 embedding 和同一 `output_scale`，目前仅代表 LUT
离线数值损失，尚未代表端到端 ROUGE-L。

当前 `LLMType::INT4` 只是枚举占位：`getLLMTypeSize(INT4)` 返回 1，`TokenEmbeddingLut` 按每元素字节数计算 row offset，并且只实现了 INT8→INT16 转换。因此仅设置 `embeddingFileType: INT4` 或将 INT16 文件改名为 INT4 都不能工作。

推荐新增带 header 的 `G4LUTI4` packed LUT：记录 magic/version、rows、cols、group_size、data/scale offset、scale 类型、graph `output_scale` 和校验信息；数据区 row-major，每 byte 存两个 signed 4-bit 值，scale 区保存每行每 group 的 scale。Embedding 的 cols 为 hidden size，PLE 的 cols 为 `num_layers*d_per_layer`。

导出流程：对已完成 Gemma sqrt 缩放的 LUT 按 group 计算 `scale=max(abs(x))/7`，将 `round(x/scale)` 裁剪到 `[-8,7]` 后打包。Runtime 的 INT4→INT16 路径按 token 定位 packed row，解出 nibble，并计算 `q16=round(q4*group_scale/output_scale)` 后裁剪到 INT16。不能直接符号扩展 q4，因为 group scale 不同；首版可用 global scale 做功能验证，但精度通常较差。

Runtime 还必须从 header 读取 vocab/shape，不能从文件大小反推；`getEmbSizeBytes()` 应返回输出行的 `cols*2`，不能返回 packed 文件行大小。配置应为 `modelInputType: INT16`、`embeddingFileType: INT4`，并分别指向 `embedding_int4_g128.bin` 和 `ple_int4_g128.bin`。完整词表的 packed 数据理论大小约为 201,326,592 B 和 1,174,405,120 B，另加 header/scale/对齐开销。

验证顺序：格式校验 → FP LUT 与解包 INT16 数值对齐 → x86 图验证 → fix-shape/surgery/cut/ncc → 单 prompt 设备初始化 → 5/6 条设备质量与性能 benchmark。重点记录饱和率、cosine/最大误差、ROUGE-L、token match、CPU 解包开销和 RSS。

## 与 LiteRT-LM NPU PLE 路径的区别

不要把外置 LUT runtime 与 LiteRT-LM 的模型内 PLE 查表混为一谈。`LiteRT-LM/runtime/executor/npu/llm_litert_npu_embedder.cc` 的 `HWPerLayerEmbeddingLookup` 已能读取 LiteRT 模型内嵌的 INT4 embedding-lookup 常量表，并解包为 FP32 或 INT16；它不解析本文设计的外置 `.bin` LUT，也不提供通用 group-wise 文件格式。

该模型内路径假设词表大小固定为 262144、INT4 行维度为偶数（行字节数使用 `dim / 2`）、per-channel scale 按 token 行索引；INT16 输出再使用子图输出的 per-tensor scale/zero point 量化。LiteRT 模型常量表与带 header、按 group 保存 scale 的独立 INT4 文件属于两种存储协议。

LiteRT-LM 模型内 PLE 解包的详细代码分析见[代码分析](litert-lm-npu-ple-int4-unpack-analysis.md)。

当前 Gemma4 workspace 的 vendor cmdline tool 实际目录为
`third_party/llm_cmdline_tool-v1.11.1/`，构建入口应由脚本位置推导仓库根目录，
再以相对仓库路径定位 vendor 和 patches，不能依赖旧的 `/root/g4/repo` 或
`llm_cmdline_tool-gemma4_release` 路径。

## v1 首版实现冻结

当前实现冻结为 `G4LUTI4` v1：固定 96-byte little-endian header、per-group FP32
scale、signed low-nibble-first packed INT4，以及 INT16 输出 requantization。
`group_size == cols` 兼容 per-row，group-wise scale 由 header 描述。外部 LUT runtime 在
`TokenEmbeddingLut` 中读取 header、使用 header 的 rows/cols 定位 embedding/PLE，
并按 `round(q4 * lut_scale / output_scale)` 生成 INT16。

当前 `llm_cmdline_tool-v1.11.1` 已通过 `rotEmbNumRealFreqs` 处理 INT16 partial
rotary；旧版 `kPartialRotaryFactor` patch 与当前源码不匹配，已移除。构建脚本对
后续 patch 使用正向 dry-run / 反向 dry-run 双重判断，任意不兼容状态直接失败。

设计、实现与验证的完整记录位于 Gemma4 项目的
`docs/gemma4-embedding-int4-implementation-record-2026-10-21.md`，实验日志目录为
`verify_logs/embedding_int4_v1_20261021/`。当前 G4LUTI4 v1 已完成离线 round-trip、
RoPE 对齐、真实 runtime bit-exact 和 NDK 完整编译；MDLA 与设备验证仍需按该记录
逐步追加命令、产物、checksum、exit code 和指标。

2026-10-21 新增 `scripts/embedding_int4/eval_hf_input_lut.py` host proxy：只替换 HF
输入 embedding lookup，保留 tied LM head 和原始 PLE，用于绕过当前 x86
`mtk_inference_quantized_llm` 不支持外部 LUT 注入的限制。group64 在 screen6 六条
prompt 上相对同一 FP32 HF 基线平均 ROUGE-L 为 `0.9466`，最低 `0.8462`；group128
平均为 `0.6641`，当前首选 group64。该结果仍不能替代 Android runtime 的设备
functional test。

当前 NP8 图的 `input_embeds_0` 为 INT16（scale `0.0006681208033114672`），
同一 host proxy 还重建了 INT8 embedding + PLE float 控制组：原始 FP16 embedding 按
`input_embeds_0` scale `0.0006681208033114672` 量化为 INT8，再模拟 runtime 的
INT8→INT16 sign extension，PLE 保持 float；screen6 平均 ROUGE-L 为 `0.8522`。
历史 `0.9213` 实验的 PLE 同样为 INT8，逐条 ROUGE-L 为
`0.8791 / 0.9346 / 0.8251 / 1 / 1 / 0.8889`，最低 `0.8251`，不能与本控制组混用。INT8 原始 bin 已清理，
本次结果属于按 runtime 语义重建，恢复真实 bin 后需做 bit-exact 对拍。

`per_layer_emb_0` 仍为 FP32、没有 INT16 scale。因此已有 embedding INT8 方案应先作为
控制基线，INT4 embedding 作为对照实验；PLE 已实现独立的 INT4→FP32 路径，不能直接
套用 INT4→INT16 的 output header 和 requantization 公式。

2026-10-21 已使用 vendor 真实 `TokenEmbeddingLut` 实现完成 G4LUTI4 group64
bit-exact 验证：直接链接 `token_embedding.cpp`、`file_source.cpp` 和 mmap 文件读取代码，
覆盖 15 个 token（含 group 边界及 vocab 首尾），共 23,040 个 INT16 元素，与 Python
参考结果 `mismatches=0`、`max_abs_diff=0`。结果位于项目的
`verify_logs/embedding_int4_runtime_bitexact_20261021/summary.json`。

2026-10-21 已实现 PLE INT4→FP32：G4LUTI4 header 使用独立的 `output_type=FP32`，
runtime 按 `FP32 = q4 * group_scale` 解包，配置使用
`pleFileType: INT4`、`pleInputType: FP32`。PLE group64 文件大小为
`1,321,205,856 B`，离线 RMSE `0.00726518`；真实 vendor runtime 覆盖 15 个 token、
134,400 个 FP32 元素，`mismatches=0`、`max_abs_diff=0`。结果位于项目的
`verify_logs/ple_int4_v1_group64_20261021/bitexact_summary.json`。

同日 host 质量验证显示，PLE group64 INT4→FP32 单独使用时平均 ROUGE-L 为 `0.7601`
（最低 `0.2074`）；叠加 embedding group64 INT4 后平均为 `0.6967`（最低 `0.3750`）。
因此当前推荐仍是 embedding group64 INT4 + PLE float；PLE group64 INT4 仅完成了
runtime 功能和 bit-exact 验证，尚未通过质量门禁。

PLE INT8 host 尝试使用 per-tensor scale `0.008858267716535433`，`embedding float +
PLE INT8` 平均 ROUGE-L `0.8216`，叠加 embedding group64 INT4 后为 `0.8154`；两者
均未通过质量门禁。当前 PLE 图输入为 FP32，INT8→FP32 必须把 scale 纳入文件协议，
不能直接复用无 scale 的裸 INT8 LUT；因此本轮只完成 host 语义评估，保留已有
`embedding INT4 + PLE INT4` 实现，不回退。

进一步的 PLE INT8 group128 host 模拟中，`embedding float + PLE INT8 group128` 平均
ROUGE-L 为 `0.9891`、最低 `0.9348`；叠加 embedding group64 INT4 后为 `0.7829`、
最低 `0.1909`。PLE INT8 group128 单独值得继续设计带 scale 的文件协议，但与当前
embedding INT4 的组合尚未通过质量门禁；保守生产方案仍为 embedding INT4 + PLE float。

随后补跑 `Embedding INT4 group64 + PLE INT8 group64→FP32`，6 条 screen6 prompt 的
平均 ROUGE-L 为 `0.7829`、最低 `0.1909`，单条为
`0.8478 / 1 / 1 / 1 / 0.6589 / 0.1909`。该结果与 PLE INT8 group128 组合的
生成文本和 ROUGE-L 完全一致，但 group64/group128 的底层反量化数值并不相同；抽样
比较最大差异约 `0.00503`，group64 的 PLE 量化 RMSE 更低。当前结论仍是不冻结
Embedding INT4 + PLE INT8 组合。

## Embedding/PLE 各方案文件体积汇总

以下大小均为完整词表、仅统计外部 Embedding 与 PLE LUT，不包含 DLA 模型、KV cache
和运行时解包缓冲区。FP16/INT8 为实际裸文件大小；G4LUTI4 为实际 packed 文件，
已包含 header、group scale 和对齐开销。

| Embedding | PLE | Embedding 文件 | PLE 文件 | 合计 | 相对 FP16+FP16 |
|---|---:|---:|---:|---:|---:|
| FP16 | FP16 | 0.750 GiB | 4.375 GiB | **5.125 GiB** | 0 |
| INT8 | FP16 | 0.375 GiB | 4.375 GiB | **4.750 GiB** | -7.32% |
| FP16 | INT8 | 0.750 GiB | 2.188 GiB | **2.938 GiB** | -42.68% |
| INT8 | INT8 | 0.375 GiB | 2.188 GiB | **2.563 GiB** | -50.00% |
| INT4 group64 | FP16 | 0.211 GiB | 4.375 GiB | **4.586 GiB** | -10.52% |
| FP16 | INT4 group64 | 0.750 GiB | 1.230 GiB | **1.980 GiB** | -61.36% |
| INT4 group64 | INT4 group64 | 0.211 GiB | 1.230 GiB | **1.441 GiB** | -71.87% |
| INT4 group128 | FP16 | 0.199 GiB | 4.375 GiB | **4.574 GiB** | -10.75% |
| INT4 per-row/global | FP16 | 0.188 GiB | 4.375 GiB | **4.563 GiB** | -10.96% |
| INT4 group64 | INT8 group64/group128* | 0.211 GiB | 2.188 GiB | **2.398 GiB** | -53.20% |

`*` PLE INT8 group64/group128 当前是 host 语义模拟，尚未生成正式带 scale 的 INT8
文件；表中按裸 INT8 数据大小估算，实际协议文件还会增加 scale/metadata 开销。

在同一 host proxy 条件下，INT8 embedding + INT8 PLE 控制组平均 ROUGE-L 为 `0.9460`
（最低 `0.8462`），INT4 group64 embedding + INT4 group64 PLE 为 `0.6967`
（最低 `0.3750`），平均下降 `0.2493`。历史动态量化实验的 `0.9213` 仍不作为本节
LUT-only 控制组。INT4+INT4 runtime 实现和产物保留，但当前质量结论为不通过。
