# Gemma4 Embedding/PLE LUT x86 验证任务归档（2026-10-27）

## 1. 任务状态

本阶段任务已完成。验证对象是生产版 `TokenEmbeddingLut` 在 x86 上对 Gemma4 Embedding/PLE LUT 的查表逻辑，不等价于 Android/MDLA 端到端推理验收。

最终门禁：

- LUT bit-exact 正确性：8/8 PASS。
- 7 档 token 延迟矩阵：no-prefetch 336/336 PASS，prefetch 168/168 PASS。
- 7 档 token 资源矩阵：no-prefetch 168/168 PASS，prefetch 168/168 PASS。
- Python 语法检查、`git diff --check`：PASS。

## 2. 生产逻辑链路

```text
LUT 文件
  → TokenEmbeddingLut 构造
  → 文件映射/可选整表 prefetch
  → lookupEmbedding(tokens, output, output_bytes)
  → 按 token 行读取
  → INT8 或 G4LUTI4 INT4 解码
  → 按 output type 写入 INT16/FP16
  → checksum 校验与耗时统计
```

INT4 使用 G4LUTI4 文件布局：96-byte header、group scale 区、packed nibble data 区。当前生产实现支持 group32/group64/group128；本次验证使用的 INT4 资产为 group64。

## 3. 两种内存策略

### no-prefetch

- 构造 LUT 时不主动读取整个 LUT。
- lookup 时按 token 行访问映射文件。
- 内存主要随实际访问 token 数增长。
- 初始化成本低，但首次访问可能产生缺页。

### prefetch

- 构造 LUT 后主动预取整个映射文件。
- 首次查表较稳定，部分 INT8 LUT warm lookup 更快。
- 初始化耗时为秒级，RSS/PSS 接近或部分反映整个 LUT 的驻留规模。
- 对完整 PLE LUT 内存压力很大。

## 4. 指标定义

单次 lookup 的输入为 `token_count` 个 token。

- `first_lookup_us`：首次读完全部 token 的耗时。
- `all_tokens_read_us_avg`：warm iterations 中，一次读完全部 token 的平均耗时。
- `all_tokens_read_us_total`：所有 warm iterations 读完全部 token 的累计耗时。
- `latency_us_avg/p50/p95/p99`：同一批全部 token 的 lookup 延迟统计。
- `tokens_per_sec`：`token_count / latency_seconds`。
- `rss_avg_mib`：资源采样期间进程 RSS 平均值。
- `rss_peak_mib`：采样到的 RSS 峰值。
- `pss_peak_mib`：采样到的 PSS 峰值。
- `cpu_avg_percent`：采样区间内进程 CPU 平均使用率。
- `minor_page_faults/major_page_faults`：进程运行期间缺页计数。

注意：`all_tokens_read_us_avg` 是一次批量 lookup 的总耗时，不是单个 token 的耗时；如需单 token 平均值，应再除以 `token_count`。

## 5. 测试矩阵

### LUT 组合

| 组合 | 词表 | 文件类型 | 输出类型 |
|---|---:|---|---|
| full Embedding | 262144 | INT8 | INT16 |
| full PLE | 262144 | INT8 | INT16 |
| full Embedding | 262144 | INT4 | INT16 |
| full PLE | 262144 | INT4 | FP16 |
| pruned Embedding | 122857 | INT8 | INT16 |
| pruned PLE | 122857 | INT8 | INT16 |
| pruned Embedding | 122857 | INT4 | INT16 |
| pruned PLE | 122857 | INT4 | INT16 |

### token 矩阵

```text
64, 128, 256, 512, 1024, 2048, 4096
```

no-prefetch 同时覆盖 sequential/random；prefetch 覆盖 sequential。每个 case 重复 3 次，warmup=10，iterations=20。

## 6. 结果位置

- bit-exact：`verify_logs/gemma4_embedding_lut_x86_correctness_20261026/`
- warm token 延迟：`verify_logs/gemma4_embedding_lut_x86_tokens_20261027/`
- token CPU/RSS/PSS：`verify_logs/gemma4_embedding_lut_x86_tokens_resource_20261027/`
- token200 prefetch 对比：`verify_logs/gemma4_embedding_lut_x86_token200_20261026/`
- 最终汇总：`docs/gemma4-embedding-ple-lut-x86-final-report-20261026-to-20261027.md`

每个矩阵目录中的 `comparison.csv` 用于汇总；每个 case 目录中的 `result.json` 保存单次完整结果，`resource_samples.tsv` 保存 10 ms 资源采样序列。

## 7. 结论与后续使用规则

1. x86 查表逻辑和 INT4/INT8 解码已验证正确。
2. no-prefetch 适合内存预算紧张、请求复用率不高的场景。
3. prefetch 只应在设备内存允许且 LUT 会被高频重复访问时考虑；不能仅根据 warm lookup 延迟决定。
4. RSS/PSS 不是 LUT 文件大小，也不是设备 DMA-BUF/NPU 内存；设备端必须单独采集。
5. 未来重复实验应固定生产 binary、manifest、token counts、warmup、iterations、重复次数和采样间隔，并将结果写入新的日期目录。

## 8. 复现入口

- `scripts/gemma4_embedding_benchmark/verify_correctness.py`
- `scripts/gemma4_embedding_benchmark/run_lut_benchmark.py`
- `docs/gemma4-embedding-ple-lut-x86-command-log-20261026.md`
