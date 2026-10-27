# Gemma4 Embedding/PLE LUT x86 独立验证程序设计

- 版本：v1
- 日期：2026-10-26
- 状态：已实现；设计约束见本文，验证结果见[最终报告](gemma4-embedding-ple-lut-x86-final-report-20261026-to-20261027.md)
- 适用对象：完整词表 262144、裁剪词表 122857；Embedding/PLE INT8 和 G4LUTI4 INT4

## 1. 目标与边界

本程序独立验证 Embedding/PLE LUT 在 x86 CPU 上的：

1. 查表正确性；
2. 查表延迟、吞吐和内存带宽；
3. CPU 平均/峰值使用率；
4. RSS、VmHWM、PSS 和缺页行为；
5. INT8 与 INT4、完整词表与裁剪词表之间的差异。

程序不替代完整 `mtk_inference_quantized_llm` x86 oracle，也不验证 TFLite/MDLA 图计算。性能核心必须复用生产版 `TokenEmbeddingLut::lookupEmbedding()`，避免 benchmark 自己重写解码逻辑。

当前 Gemma4 生产实现位于 cmdtool v1.11.1：

```text
third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_helper/token_embedding.cpp
third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_helper/include/token_embedding.h
```

已有 `scripts/embedding_int4/runtime_lut_probe.cpp` 直接链接这两个接口对应的实现。
`third_party/llm_cmdline_tool-v1.9.2/` 是旧版实现，不作为当前 Gemma4 INT4 benchmark 的生产基线。

## 2. 目录设计

Gemma4 专用 benchmark 放在：

```text
scripts/gemma4_embedding_benchmark/
├── lut_benchmark.cpp
├── run_lut_benchmark.py
├── lut_reference.py
└── README.md
```

已有通用 G4LUTI4 工具保留在 `scripts/embedding_int4/`，复用：

- `lut_format.py`：Header、scale、pack/unpack；
- `runtime_lut_probe.cpp`：已有 runtime bit-exact 查表入口。

实验结果统一写入：

```text
verify_logs/gemma4_embedding_lut_x86_<timestamp>/
```

## 3. 支持的文件格式

G4LUTI4 header、编码和兼容规则以[Runtime 格式契约](../runtime/gemma4-external-lut-g4luti4-int4.md)
为准；benchmark 不另行定义一套解码格式。

### 3.1 INT8

支持：

```text
embedding_int8.bin
ple_int8.bin
```

INT8 文件没有 G4LUTI4 Header，必须从 YAML 或命令行获得：

- rows/vocab size；
- cols/hidden size；
- file type；
- output type。

生产 runtime 语义为：

```text
INT8 file → INT16 output
```

### 3.2 INT4

支持：

```text
embedding.g4luti4
ple.g4luti4
```

从 Header 读取 shape、group size、输出类型、scale 和数据区偏移；程序对实际读取路径做
正确性校验。不同输出类型的实测覆盖范围见[最终报告](gemma4-embedding-ple-lut-x86-final-report-20261026-to-20261027.md)。

## 4. 程序分层

### 4.1 C++ benchmark

`lut_benchmark.cpp` 负责：

- 构造生产版 `TokenEmbeddingLut`；
- 调用 `lookupEmbedding()`；
- 运行 warmup 和 measured iterations；
- 统计纳秒级/微秒级延迟；
- 计算 checksum，防止热循环被优化掉；
- 输出 latency 样本和最终指标。

不在 benchmark 内重新实现 INT4 nibble 解包或 scale 计算。

### 4.2 Python driver

`run_lut_benchmark.py` 负责：

- 组织完整测试矩阵；
- 绑定 CPU affinity；
- 启动资源采样；
- 运行多轮 benchmark；
- 汇总 P50/P95/P99、平均值和峰值；
- 生成 JSON、CSV、TSV 和 Markdown。

### 4.3 Python reference

`lut_reference.py` 负责：

- 读取 INT8 和 G4LUTI4；
- 生成 reference output；
- 与 C++ runtime output 做 bit-exact 或误差比较。

Python 只用于正确性 reference，不用于最终性能结论。

## 5. Prefetch 设计

当前 `TokenEmbeddingLut` 默认调用 `FileSource::prefetch()`：

- mmap LUT 文件；
- 按 OS page size 逐页触碰一个字节；
- 使文件页在首次 lookup 前进入 page cache；
- 不创建一份额外 heap copy；
- 不保证页面永远驻留，也不等于进入 CPU L1/L2 cache。

benchmark 必须分为：

### Prefetch on

测量：

- 初始化时间；
- prefetch 时间；
- 稳态 lookup；
- 初始化阶段 RSS/PSS 峰值。

### Prefetch off

测量：

- mmap 初始化；
- 首次 lookup；
- 首次 page fault；
- 冷启动 RSS/PSS 增长。

结果必须记录：

```json
{
  "prefetch": true
}
```

不能只从第一次 lookup 开始计时，否则会漏掉预取成本。

## 6. 测试矩阵

### 6.1 资产矩阵

| 词表 | LUT | 文件类型 | 输出类型 |
|---|---|---|---|
| 完整 262144 | Embedding | INT8 | INT16 |
| 完整 262144 | PLE | INT8 | INT16 |
| 完整 262144 | Embedding | INT4 | INT16 |
| 完整 262144 | PLE | INT4 | FP16/FP32 |
| 裁剪 122857 | Embedding | INT8 | INT16 |
| 裁剪 122857 | PLE | INT8 | INT16 |
| 裁剪 122857 | Embedding | INT4 | INT16 |
| 裁剪 122857 | PLE | INT4 | FP16/FP32 |

### 6.2 访问矩阵

```text
token_count: 1、64、128、256、1024、2048、4096
access_pattern: sequential、random
prefetch: on、off
threads: 首先固定 1，后续扩展 2/4
warmup: 10
iterations: 1000
repeats: 5
resource_interval: 10 ms
```

第一阶段固定单线程，避免线程安全、调度和 cache 干扰。

## 7. 指标定义

### 延迟与吞吐

- `latency_us_avg`
- `latency_us_p50`
- `latency_us_p95`
- `latency_us_p99`
- `tokens_per_sec`
- `output_elements_per_sec`
- `output_bytes_per_sec`

### CPU

- 进程 CPU 平均值；
- 进程 CPU 峰值；
- 线程 CPU 使用率；
- CPU affinity；
- 逻辑 CPU 数量。

多线程 CPU 使用率允许超过 100%，必须同时记录线程数和归一化 CPU%。

### 内存

- RSS average/peak；
- VmHWM；
- PSS peak；
- VmSize；
- LUT mmap 的 Rss/Private_Clean/Shared_Clean；
- minor/major page faults；
- context switches。

文件大小不能直接当作运行时 RSS；必须保留 mmap 页实际驻留数据。

## 8. 正确性验证

每个 LUT 使用边界和典型 token：

```text
0、1、2、7、8、63、64、127、128、
255、256、65535、131071、vocab_size-1
```

比较：

```text
C++ TokenEmbeddingLut output
vs
Python reference output
```

判定：

- INT8→INT16：bit-exact；
- INT4→INT16：bit-exact；
- INT4→FP16/FP32：记录 max/mean absolute error、relative error、cosine similarity；
- 所有 token 不越界；
- checksum 稳定；
- 无 SIGSEGV 或异常退出。

## 9. 结果组织

每次实验：

```text
verify_logs/gemma4_embedding_lut_x86_<timestamp>/
├── config.json
├── metadata.json
├── summary.md
├── comparison.csv
├── correctness/
│   ├── full_embedding.json
│   ├── full_ple.json
│   ├── pruned_embedding.json
│   └── pruned_ple.json
└── runs/
    ├── full_emb_int8_warm_seq_t1/
    │   ├── result.json
    │   ├── latency_samples.csv
    │   ├── resource_samples.tsv
    │   └── stdout.log
    └── ...
```

`metadata.json` 必须记录：

- asset 路径；
- SHA256；
- vocab size；
- rows/cols；
- group size；
- file/output type；
- prefetch；
- token pattern；
- CPU affinity；
- 编译器；
- git commit。

`comparison.csv` 用于横向比较：

```text
full/pruned
embedding/ple
INT8/INT4
INT16/FP16/FP32
token_count
prefetch
sequential/random
latency
throughput
CPU
RSS/PSS
```

## 10. 实施顺序

1. 实现 C++ 单线程 INT8/INT4 lookup benchmark；
2. 实现 INT8/INT4 reference correctness；
3. 加入 latency 样本；
4. 加入 RSS/PSS/VmHWM/缺页采样；
5. 完成完整词表与裁剪词表矩阵；
6. 生成 comparison.csv 和 summary.md；
7. 通过 bit-exact 后再测试多线程；
8. 最后与完整 x86 TFLite oracle 结果分开记录。

## 11. 验收标准

程序验收必须满足：

- INT8→INT16 bit-exact；
- INT4→INT16 bit-exact；
- G4LUTI4 Header 和 group size 校验通过；
- 完整词表、裁剪词表均可运行；
- prefetch on/off 均有结果；
- 原始 latency/resource 采样完整；
- 结果中可区分初始化、首次 lookup 和 warm lookup；
- 不把 host LUT benchmark 结果误称为完整 TFLite/MDLA 推理结果。

## 外置 LUT 的验证边界与顺序

可以在 x86 上验证 Embedding/PLE，但分为两层：

1. **LUT 数值级验证：可以直接进行。** 使用 `scripts/embedding_int4/lut_format.py` 读取 G4LUTI4 header、group scale 和 packed INT4，验证 unpack、scale、输出 INT16/FP16/FP32 结果；`scripts/embedding_int4/runtime_lut_probe.cpp` 可进一步做真实 runtime 语义的 bit-exact 查表验证。
2. **Host proxy 质量验证：可以进行。** `scripts/embedding_int4/eval_hf_input_lut.py` 可将 Embedding/PLE LUT 查表结果接入 HF host proxy，与 FP32 基线比较 RMSE、余弦相似度和 ROUGE-L；这不是完整 TFLite/MDLA 推理。
3. **完整 x86 TFLite oracle：当前不能直接注入外部 G4LUTI4。** `mtk_inference_quantized_llm` 运行的是图内权重/张量，现有 oracle 没有外部 `.g4luti4` 注入接口。因此，完整模型的 x86 ROUGE-L 只能验证包含相同量化语义的 TFLite 图；不能仅凭 x86 oracle 证明设备 runtime 已正确解析外部 G4LUTI4。

推荐顺序：先做 G4LUTI4 bit-exact → Embedding/PLE 数值误差 → HF host proxy → 再做整图 x86 oracle → 最后做设备 benchmark。当前完整词表和裁剪词表 INT4 资产均适用该验证边界。

## 实施与结果

本文只维护 benchmark 的目标、输入边界、指标和验收设计。实际实现状态、发现的问题、
最终结果和适用限制统一见[最终验证报告](gemma4-embedding-ple-lut-x86-final-report-20261026-to-20261027.md)；
逐步复现命令见[命令记录](gemma4-embedding-ple-lut-x86-command-log-20261026.md)。
