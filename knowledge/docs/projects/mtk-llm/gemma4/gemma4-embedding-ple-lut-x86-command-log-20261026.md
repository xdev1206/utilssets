# Gemma4 Embedding/PLE LUT x86 命令记录

- 日期：2026-10-26
- 用途：记录 LUT 导出修复、x86 正确性验证、prefetch/no-prefetch 性能验证命令
- 约定：后续本主题新增执行命令继续追加到本文件，并同步项目派生文档

## 1. Python 检查

```bash
python3 -m py_compile scripts/embedding_int4/export_pruned_model_g4luti4.py scripts/gemma4_embedding_benchmark/*.py
```

## 2. 修复后重新生成裁剪词表 INT4 LUT

```bash
python3 scripts/embedding_int4/export_pruned_model_g4luti4.py \
  --model /data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it_embedding-pruning/model.safetensors \
  --output-dir assets/assets_gemma4_hessian_pruned_embint4_group64_np8_ctx4096_int16_20261026_fixed \
  --embedding-scale 0.0006681208033114672 \
  --ple-scale 0.00054931640625 \
  --group-size 64 \
  --chunk-rows 256
```

## 3. 编译正确性验证程序

```bash
g++ -std=gnu++17 -O2 -fpermissive \
  -D__fp16=HostFp16 \
  -include scripts/gemma4_embedding_benchmark/host_fp16.h \
  -include cstdint -include cstring -include cerrno \
  -include memory -include optional \
  -Ithird_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src \
  -Ithird_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/include \
  scripts/gemma4_embedding_benchmark/lut_correctness.cpp \
  third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_helper/token_embedding.cpp \
  third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_source.cpp \
  third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_mem_mapper.cpp \
  third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_direct_reader.cpp \
  -o verify_logs/gemma4_embedding_lut_x86_correctness_20261026/lut_correctness
```

## 4. 运行 8 组 LUT 正确性验证

```bash
python3 scripts/gemma4_embedding_benchmark/verify_correctness.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_correctness_20261026/lut_correctness \
  --out-dir verify_logs/gemma4_embedding_lut_x86_correctness_20261026/runs_r3
```

结果：8 PASS / 0 ERROR。

## 5. 编译 prefetch/no-prefetch benchmark

```bash
common='-std=gnu++17 -O2 -fpermissive -D__fp16=HostFp16 -include scripts/gemma4_embedding_benchmark/host_fp16.h -include cstdint -include cstring -include cerrno -include memory -include optional -Ithird_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src -Ithird_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/include'
sources='scripts/gemma4_embedding_benchmark/lut_benchmark.cpp third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_helper/token_embedding.cpp third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_source.cpp third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_mem_mapper.cpp third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/common/file_direct_reader.cpp'
g++ $common $sources -o verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_prefetch
g++ $common -DDISABLE_EMBEDDING_LUT_PREFETCH $sources -o verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_no_prefetch
```

## 6. 运行性能 smoke

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/prefetch \
  --warmup 2 --iterations 20 --repeats 1 --token-counts 1 --patterns sequential

python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_no_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/no_prefetch \
  --warmup 2 --iterations 20 --repeats 1 --token-counts 1 --patterns sequential
```

## 7. 运行 token_count=1/64/256 扩展 benchmark

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary <lut_benchmark_prefetch_or_no_prefetch> \
  --out-dir verify_logs/gemma4_embedding_lut_x86_extended5_20261026/<mode> \
  --warmup 2 --iterations 20 --repeats 5 \
  --token-counts 1 64 256 --patterns sequential random
```

实际输出目录：

```text
verify_logs/gemma4_embedding_lut_x86_extended5_20261026/no_prefetch/
verify_logs/gemma4_embedding_lut_x86_extended5_20261026/prefetch/
```

## 8. 受控 cold-cache benchmark

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary <lut_benchmark_prefetch_or_no_prefetch> \
  --out-dir verify_logs/gemma4_embedding_lut_x86_prefetch_controlled_smoke_20261026/<mode> \
  --warmup 2 --iterations 20 --repeats 2 \
  --token-counts 1 --patterns sequential --evict-cache
```

程序内部在每个 trial 前执行文件级：

```text
open(O_RDONLY) → posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED) → close
```

## 9. 200-token 连续/随机 benchmark

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_no_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_token200_20261026/no_prefetch \
  --warmup 10 --iterations 20 --repeats 5 --token-counts 200 --patterns sequential random

python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_token200_20261026/prefetch \
  --warmup 10 --iterations 20 --repeats 5 --token-counts 200 --patterns sequential random
```

结果目录：

```text
verify_logs/gemma4_embedding_lut_x86_token200_20261026/no_prefetch/
verify_logs/gemma4_embedding_lut_x86_token200_20261026/prefetch/
```

## 10. 结果索引

## 受控资源采样

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_no_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_resource_20261026/no_prefetch \
  --warmup 10 --iterations 20 --repeats 3 --token-counts 200 --patterns sequential \
  --evict-cache --sample-resources --sample-interval-ms 10

python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_resource_20261026/prefetch \
  --warmup 10 --iterations 20 --repeats 3 --token-counts 200 --patterns sequential \
  --evict-cache --sample-resources --sample-interval-ms 10
```

结果：两种模式各 24 runs，全部 PASS；最终汇总见
`gemma4-embedding-ple-lut-x86-final-report-20261026-to-20261027.md`。

## 7 档 token 总读取耗时矩阵

默认 token 数为 `64 128 256 512 1024 2048 4096`。`all_tokens_read_us_avg` 是一次 lookup 读完全部 token 的平均耗时，`all_tokens_read_us_total` 是所有 iterations 的累计耗时。

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_no_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_tokens_20261027/no_prefetch \
  --warmup 10 --iterations 20 --repeats 3 --patterns sequential random

python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_tokens_20261027/prefetch \
  --warmup 10 --iterations 20 --repeats 3 --patterns sequential
```

结果：no-prefetch 336 runs、prefetch 168 runs，全部 PASS。完整矩阵在全局最终报告，原始记录在两个输出目录的 `comparison.csv` 和各 case 的 `result.json`。

## 7 档 token CPU/RSS/PSS 采样

```bash
python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_no_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_tokens_resource_20261027/no_prefetch \
  --warmup 10 --iterations 20 --repeats 3 --patterns sequential \
  --sample-resources --sample-interval-ms 10

python3 scripts/gemma4_embedding_benchmark/run_lut_benchmark.py \
  --manifest verify_logs/gemma4_embedding_lut_x86_correctness_20261026/manifest.json \
  --binary verify_logs/gemma4_embedding_lut_x86_perf_smoke_20261026/lut_benchmark_prefetch \
  --out-dir verify_logs/gemma4_embedding_lut_x86_tokens_resource_20261027/prefetch \
  --warmup 10 --iterations 20 --repeats 3 --patterns sequential \
  --sample-resources --sample-interval-ms 10
```

结果：两种模式各 168 runs，全部 PASS；资源字段和采样序列写入各自输出目录。

| 验证内容 | 结果目录 |
|---|---|
| LUT 正确性 | `verify_logs/gemma4_embedding_lut_x86_correctness_20261026/` |
| Warm 性能扩展 | `verify_logs/gemma4_embedding_lut_x86_extended5_20261026/` |
| Cold-cache prefetch smoke | `verify_logs/gemma4_embedding_lut_x86_prefetch_controlled_smoke_20261026/` |
| 200-token 连续/随机 | `verify_logs/gemma4_embedding_lut_x86_token200_20261026/` |
