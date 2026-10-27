# Gemma4 外置 Embedding/PLE G4LUTI4 INT4

## 这是什么

G4LUTI4 是 Gemma4 部署中由 `llm_cmdline_tool` Runtime 使用的外置 LUT 文件格式，
不是 Gemma4 TFLite 图内部的通用权重格式，也不是 tokenizer 文件格式。

它服务于两个外置查表模块：

```text
HF/MTK 原始表
    ├── embedding_fp16/int8.bin ──┐
    │                              ├── llm_cmdline_tool::TokenEmbeddingLut
    └── ple_fp16/int8.bin ────────┘
                                   └── G4LUTI4 解包/反量化 → graph 输入
```

实际文件含义：

| 文件 | Runtime 用途 | Gemma4 图输入 | 当前目标 |
|---|---|---|---|
| `embedding_int4.bin` | token embedding 查表 | `input_embeds_0` | INT4 → INT16 |
| `ple_int4.bin` | 每层 PLE 查表 | `per_layer_emb_0` | INT4 → INT16 |

对应 Runtime 实现：

```text
third_party/llm_cmdline_tool-v1.11.1/
└── jni/prebuilt/src/llm_helper/token_embedding.cpp
    └── TokenEmbeddingLut
```

## 文件布局

```text
G4LUTI4 file
├── 96-byte little-endian header
├── FP32 group scales
└── packed signed INT4 data
```

完整布局：

```text
header[96]
  + scales[rows × groups_per_row × sizeof(float)]
  + data[rows × ceil(cols / 2)]
```

## 96-byte Header

| 偏移 | 类型 | 字段 | 取值/作用 |
|---:|---|---|---|
| 0 | `char[8]` | `magic` | `G4LUTI4\\0` |
| 8 | `uint32` | `version` | `1` |
| 12 | `uint32` | `headerBytes` | `96` |
| 16 | `uint64` | `rows` | 词表行数 |
| 24 | `uint64` | `cols` | 每行向量维度 |
| 32 | `uint32` | `groupSize` | 仅 32/64/128 |
| 36 | `uint32` | `scaleType` | `1 = FP32` |
| 40 | `uint32` | `outputType` | `2 = INT16`，`1 = FP32` |
| 44 | `uint32` | `flags` | `1 = low nibble first` |
| 48 | `uint64` | `scaleOffset` | scale 区偏移 |
| 56 | `uint64` | `dataOffset` | packed data 区偏移 |
| 64 | `uint64` | `scaleBytes` | scale 区大小 |
| 72 | `uint64` | `dataBytes` | packed data 区大小 |
| 80 | `float32` | `outputScale` | INT16 输出 scale |
| 84 | `int32` | `zeroPoint` | 固定为 0 |
| 88 | `uint8[8]` | `reserved` | 保留字段 |

总 Header 大小固定为 96 字节。

## INT4 数据编码

每个 group 使用对称 INT4：

```text
scale = max(abs(group_values)) / 7
q4 = round(value / scale)
q4 = clamp(q4, -8, 7)
```

每两个 q4 打包为一个 byte：偶数列放低 nibble，奇数列放高 nibble。

```text
q4 = [-1, 7]
-1 → 0xF
 7 → 0x7
packed byte = 0x7F
```

Runtime 读取 nibble 后执行符号扩展：

```text
nibble >= 8 ? nibble - 16 : nibble
```

支持的 group size 只有：

```text
group32, group64, group128
```

## Runtime 输出

### Embedding INT4 → INT16

```text
int16 = round(q4 × group_scale / outputScale) + zeroPoint
int16 = clamp(int16, -32768, 32767)
```

### PLE INT4 → INT16

使用同样的解包和反量化公式，输出写入 `per_layer_emb_0` 的 INT16 输入缓冲区。

历史实现还支持 PLE INT4 → FP32：

```text
fp32 = q4 × group_scale
```

但这不是当前目标配置。

## PTQ 配置语义

PTQ 阶段：

```json
{
    "embeddings": "int8",
    "ple": "int8",
    "lut_quant": {
        "embedding": {
            "logical_precision": "int4",
            "storage_precision": "int8",
            "group_size": 64,
            "output_type": "int16",
            "format": "G4LUTI4"
        },
        "ple": {
            "logical_precision": "int4",
            "storage_precision": "int8",
            "group_size": 64,
            "output_type": "int16",
            "format": "G4LUTI4"
        }
    }
}
```

这里的 `int8` 只表示 PTQ 中间容器使用 INT8；实际有效值必须是 `[-8,7]`，不能按
普通 INT8 的 `[-128,127]` 处理。最终导出时，INT8 容器中的 q4 值被 pack 成真正的
G4LUTI4 数据。

### q4 INT8 中间容器的固定存储结构

该中间格式固定为三个同名文件，不使用单一二进制文件，也不在 q4 数据中隐式编码
group size：

```text
<name>.q4.i8          # row-major q4 值，dtype=int8，取值 [-8, 7]
<name>.q4.i8.scales.f32  # 每行每组一个 little-endian float32 scale
<name>.q4.i8.json      # shape、group_size 和文件关联信息
```

对于权重形状 `rows × cols` 和 `group_size=G`：

```text
q4.shape              = [rows, cols]
groups_per_row        = ceil(cols / G)
scales.shape          = [rows, groups_per_row]
group_id               = col // G
```

JSON 必须保存 `group_size`、`rows`、`cols`、`groups_per_row`、数据文件名和 scale
文件名。`.q4.i8` 和 `.scales.f32` 本身不包含 group size；读取端必须先读取并校验
JSON，不能仅凭文件大小推断。最后一组允许不足 G 个元素，但 scale 仍按该行最后一组
单独保存。该中间格式不包含 header、不做 nibble packing；真正的 4-bit packing 和
自描述的 group size 位于后续 G4LUTI4 96-byte header。

## SDK PTQ 接线边界

当前 SDK 的 PTQ 在模型转换后通过 LUT dump 入口导出 Embedding/PLE 文件，并没有
独立的 Embedding/PLE fake-quant graph 节点。启用有效 `lut_quant.embedding` 后，
Embedding dump 入口调用 grouped q4 fake-quant，并输出上述三文件；未配置 `lut_quant`
时继续输出普通 INT8 或 FP16 文件。该接线只建立 PTQ 中间容器，尚未代表最终
G4LUTI4 打包，也未改变 Runtime 输入类型。PLE 接线应保持独立 patch，防止相似 dump
函数的上下文匹配错误。

随后 PLE 使用独立 dump patch 接入相同流程：有效 `lut_quant.ple` 时输出
`ple_q4.i8`、`ple_q4.i8.scales.f32` 和 `ple_q4.i8.json`，旧配置继续输出普通
`ple_int8.bin` 或 `ple_fp16.bin`。Embedding 与 PLE 的 group32、group64、group128
均需分别验证；这一步仍不生成最终 G4LUTI4，也不修改 Runtime 解析。

最终导出使用独立的 `pack_q4_container_g4luti4.py`：读取 JSON 的 group size，原样
复制 FP32 group scale，并对 q4 INT8 值执行 low-nibble-first packing，不重新量化。
因为中间容器不保存 Runtime INT16 output scale，导出命令必须显式提供
`--output-scale`。导出器已覆盖 group32/64/128 和奇数列数的 bit-exact 回读验证，
但尚未接入 PTQ 主脚本或设备测试。

导出器现在也支持从 PTQ `*_info_*.json` 的 `input_scales[index]` 自动读取
`output_scale`，并保留显式 `--output-scale` 覆盖；两者互斥。Embedding 通常使用
第 0 层 graph 输入的 `input_scales[0]`，PLE 必须使用其自身对应 graph 输入的
scale，不能无条件复用 Embedding scale。导出器还支持按 `input_names`/
`output_names` 的 tensor 名称选择，并在自动读取时要求对应 zero point 为 0；名称
选择和 index 选择互斥。

PTQ 后处理使用 `scripts/embedding_int4/export_q4_luts_from_ptq.py`：Embedding 和
PLE 必须分别提供对应的 PTQ info 文件及 tensor selector，wrapper 确认 q4 三件套后
调用 G4LUTI4 packer，不默认复用 Embedding scale。当前为 PTQ 完成后的显式后处理，
尚未修改 SDK `ptq.py` 内部流程。

Gemma4 v2 的部署侧后处理入口为
`scripts/deploy/gemma4_v2/3d_export_g4luti4.sh`。它在 PTQ 完成后调用 wrapper，
Embedding 可自动选择唯一的 layer-0 info，PLE 必须显式提供对应 info 和 tensor
selector；缺少 PLE scale 时直接失败，不复用 Embedding scale。

Runtime 配置：

```yaml
modelInputType: INT16
embeddingFileType: INT4
pleFileType: INT4
pleInputType: INT16
```

## 兼容性规则

`lut_quant` 是可选的显式 INT4 功能开关。没有该字段时，旧配置保持原语义：普通
`embeddings: int8`/`ple: int8` 仍是普通 INT8，`float` 仍使用原有浮点 LUT；SDK
不会根据 `int8` 自动推断逻辑 INT4。SDK 中 `ple` 未配置时，PLE 继续继承
`embeddings` 的精度。

启用 `lut_quant` 后必须同时配置 Embedding 和 PLE，并满足：

```text
embeddings == int8
ple == int8
logical_precision == int4
storage_precision == int8
output_type == int16
group_size ∈ {32, 64, 128}
```

部分配置、`float` 与 `lut_quant` 混用、不支持的 group size 或非 INT16 输出都必须
直接报错，不能静默回退到普通 INT8。只有完整校验通过后，Runtime 才使用
`embeddingFileType: INT4`、`pleFileType: INT4` 和 `pleInputType: INT16`；旧配置继续
使用原有 INT8/FP16 文件和 YAML。

## 当前代码位置

| 功能 | 文件 |
|---|---|
| Python Header、pack/unpack、读写 | `scripts/embedding_int4/lut_format.py` |
| 原始表转 G4LUTI4 | `scripts/embedding_int4/pack_raw_lut_int4.py` |
| PTQ INT8 容器转 packed INT4 | `scripts/embedding_int4/pack_ptq_int8_lut_int4.py` |
| Runtime 解包和 INT16 输出 | `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_helper/token_embedding.cpp` |
| PTQ 配置契约 | `scripts/embedding_int4/lut_quant_config.py` |

## 尺寸示例：完整词表、group64

| 表 | 形状 | packed data | scales | 总大小 |
|---|---:|---:|---:|---:|
| Embedding | `262144×1536` | 201,326,592 B | 25,165,824 B | 226,492,512 B |
| PLE | `262144×8960` | 1,174,405,120 B | 146,800,640 B | 1,321,205,856 B |

总大小包含 96-byte Header。

## MTK PTQ 环境版本匹配

`mlkits 10.4.9` 要求 `mtk-converter>=10.2.0`。Python 3.12 环境应使用
Neuropilot SDK Premium 10.0.2 离线包中的 `mtk_converter 10.6.0` cp312 wheel；
`mtk-converter 9.8.0` 会在 PTQ 的 Quokka 初始化阶段失败。

## 2026-10-23 设备 benchmark

local RoPE `localHeadDim` 修复后，使用 INT4 group64 资产完成 t0-t5 六条 prompt 验证，
`max_new_tokens=30`，全部无 SIGSEGV。输入/输出 token 使用设备 SentencePiece tokenizer
统计，资源采样名义 300 ms，实际 365--378 ms。

结果：`verify_logs/device_gemma4_int4_benchmark_20261023_101121/benchmark_summary.json`。

| prompt | 输入 token | 输出 token | prefill tok/s | decode tok/s | CPU avg/peak | RSS avg/peak MiB | PSS peak MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| t0 | 104 | 17 | 341.258 | 13.5224 | 72.81/195.31% | 140.94/293.28 | 109.08 |
| t1 | 104 | 23 | 1352.570 | 15.5989 | 71.98/235.92% | 144.89/340.74 | 106.44 |
| t2 | 38 | 16 | 809.367 | 14.9372 | 75.19/236.26% | 130.81/266.94 | 102.60 |
| t3 | 93 | 29 | 1014.650 | 15.0239 | 44.88/143.58% | 124.81/256.14 | 107.35 |
| t4 | 40 | 2 | 967.842 | 14.8044 | 134.69/233.70% | 126.87/272.00 | 101.28 |
| t5 | 5 | 25 | 1385.200 | 14.6023 | 60.45/233.33% | 122.45/285.23 | 100.80 |

### DMA-BUF/NeuroPilot 内存统计

设备 runner 额外生成 `*.memory.csv`，并在资源汇总中分别记录进程 RSS、DMA-BUF、
NeuroPilot counter 以及 accounting sum。DMA-BUF 优先来自
`/sys/kernel/dmabuf/buffers/*/size`，属于全设备口径；NeuroPilot 节点因厂商实现差异，
找不到时记录 `unavailable`。accounting sum 定义为组件峰值之和
`RSS peak + DMA-BUF peak + NeuroPilot peak`，可能重复计算映射 buffer，仅用于保守对账，
不代表去重后的物理总量。

2026-10-23 单条设备探测：进程 RSS 140.81 MiB，DMA-BUF 146.73 MiB（119 buffers），
NeuroPilot counter `unavailable`，accounting sum 287.55 MiB。原始记录位于
`verify_logs/device_memory_probe_20261023_111354/device_logs/t0.memory.csv`。

最终 6 条 benchmark 的 DMA-BUF 峰值为 146.73 MiB（119 buffers），NeuroPilot counter 为
`unavailable`；进程 RSS 峰值 275.35 MiB，组件峰值 accounting sum 422.08 MiB。结果位于
`verify_logs/device_gemma4_int4_memory_benchmark_20261023_1145/resource_summary.md`。

### t6 长英文 prompt

新增英文长 prompt `t6.txt`，主机 tokenizer 计数 2048，设备实际识别 2050 tokens；同一
INT4 group64 assets、`max_new_tokens=30` 运行无崩溃。Prefill 1041.76 tok/s，decode
16.7743 tok/s，RSS peak 229.05 MiB，PSS peak 129.84 MiB，VmHWM 967.93 MiB，DMA-BUF
peak 1469.95 MiB，组件峰值 accounting sum 1699.00 MiB；NeuroPilot counter 为
`unavailable`。结果目录：
`verify_logs/device_gemma4_int4_t6_2048_20261023_1200/`。

重新生成的分级 prompt 位于 `verify_logs/screen_baselines/device_prompts_v3_64_4096/`，
保持原 t0-t6 领域不变，主机 tokenizer 目标为 62/126/254/510/1022/2046/4094，预留设备
侧约 2 token 计数差，使设备侧不超过 64/128/256/512/1024/2048/4096。清单为该目录下的
`manifest.json`，生成脚本为 `scripts/device/make_balanced_prompts_v3.py`。

新 prompt 已完成设备 benchmark（同一 INT4 group64 assets，`max_new_tokens=30`），输入长度
为 64/128/256/512/1024/2048/4096，全部无崩溃。Prefill 分别为 1151.28、864.289、
871.416、1206.26、1155.83、1271.36、1324.16 tok/s；decode 分别为 15.9561、15.7883、
16.0321、15.9648、16.1788、16.0888、17.2187 tok/s。最终资源结果位于
`verify_logs/device_gemma4_int4_v3_benchmark_20261023_1230/resource_summary.md`。

后续 benchmark 默认使用 `verify_logs/screen_baselines/device_prompts_v3_64_4096/` 的
t0–t6 分级 prompt；旧 v2 prompt 仅用于历史结果复现。runner 已将该目录设为默认的
`--prompts`，无需额外参数即可使用新测试集；默认 `max_new_tokens=128`。

Embedding INT8 + Hessian 旧图的兼容性问题已定位：旧 YAML 的 `pleEmbPath` 未被当前
parser 读取，导致 PLE input 未注册（expected 38），而 graph 实际有 39 个 input。临时
YAML 改用 `plePath` 并设置 `pleFileType: INT8`、`pleInputType: INT16` 后，当前 runtime
成功运行 v3 t0–t6，全部无崩溃。结果目录：
`verify_logs/device_gemma4_embint8_hessian_v3_benchmark_20261023_1430_m128/`。
统一汇总文件 `benchmark_summary.md` 同时包含 input/output tokens、Prefill/Decode、CPU、
RSS/PSS/VmHWM、DMA-BUF、NeuroPilot 和总和内存；生成脚本为
`scripts/device/summarize_benchmark.py`。
