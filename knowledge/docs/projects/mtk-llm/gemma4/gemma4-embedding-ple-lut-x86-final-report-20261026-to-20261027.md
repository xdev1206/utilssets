# Gemma4 Embedding/PLE LUT x86 最终验证报告（2026-10-26 至 27）

## 范围与结论

本报告覆盖生产版 `TokenEmbeddingLut` 的 x86 正确性、warm lookup、prefetch/no-prefetch 以及资源采样验证；不代表设备端 NPU 推理性能。

- 正确性：8 个 LUT 组合、每个 32 个测试用例，全部 PASS；包括完整/裁剪词表、INT8/INT4、Embedding/PLE。
- 连续与随机 200-token warm lookup：同一模式下最大差异约 3%，访问模式不是当前 host 测试的主要瓶颈。
- prefetch：降低了部分首次/稳态查表延迟，但代价是主动读取大文件、秒级初始化和显著 RSS/PSS；是否启用必须结合设备内存预算与请求复用率决定。
- no-prefetch：初始化几乎为零，进程驻留内存低；首次访问成本由实际 token 行的缺页承担。

## 测试对象

| 类别 | 词表 | 文件/输出 |
|---|---:|---|
| full Embedding | 262144 | INT8 → INT16、INT4 → INT16 |
| full PLE | 262144 | INT8 → INT16、INT4 → FP16 |
| pruned Embedding | 122857 | INT8 → INT16、INT4 → INT16 |
| pruned PLE | 122857 | INT8 → INT16、INT4 → INT16 |

## 正确性门禁

8 种 LUT 组合各运行 32 个用例，最终全部通过。初次裁剪词表 INT4 检查发现 scale
区域从第 256 行起出现非有限或非正值；原因是导出器交错写 scale 与 packed data，
与 Header 声明的“完整 scale 区后接完整 data 区”不符。修复后分段写入再按完整 scale、
完整 data 合并，新资产通过 Header、shape 和 scale 检查。旧的
`..._20261025/` 裁剪 INT4 目录属于失败产物，不应用于后续 benchmark。

## Cold-cache 首次查询

受控 smoke 每种模式运行 16 组；`POSIX_FADV_DONTNEED` 均返回 0，但它只是驱逐建议。
下表为完整词表单 token 结果：

| LUT | 模式 | init ms | cold first lookup us | minor fault | major fault |
|---|---|---:|---:|---:|---:|
| Embedding INT8 | no-prefetch | 0.02 | 547.80 | 2 | 1 |
| Embedding INT8 | prefetch | 1617.09 | 2.23 | 6148 | 3073 |
| PLE INT8 | no-prefetch | 0.02 | 541.04 | 3 | 1 |
| PLE INT8 | prefetch | 12330.45 | 5.51 | 35842 | 17922 |
| Embedding INT4 | no-prefetch | 0.57 | 590.96 | 2 | 2 |
| Embedding INT4 | prefetch | 1156.31 | 8.88 | 3460 | 1730 |
| PLE INT4 | no-prefetch | 0.55 | 545.79 | 2 | 2 |
| PLE INT4 | prefetch | 6941.67 | 94.74 | 20162 | 10082 |

prefetch 将首次查询延迟转移到初始化，并增加大量缺页；这组结果用于说明延迟位置的
变化，不代表设备上的冷缓存行为。

## 连续与随机访问

完整及裁剪词表各组合的 200-token warm lookup 平均耗时如下（us）：

| LUT | 词表 | no-prefetch 连续 | no-prefetch 随机 | prefetch 连续 | prefetch 随机 |
|---|---:|---:|---:|---:|---:|
| Embedding INT8→INT16 | 262144 | 204.435 | 205.989 | 103.626 | 103.970 |
| PLE INT8→INT16 | 262144 | 1214.370 | 1177.736 | 590.908 | 606.974 |
| Embedding INT4→INT16 | 262144 | 1040.528 | 1039.806 | 1041.822 | 1040.432 |
| PLE INT4→FP16 | 262144 | 17882.640 | 17921.980 | 17966.500 | 18005.260 |
| Embedding INT8→INT16 | 122857 | 202.646 | 201.485 | 103.441 | 104.414 |
| PLE INT8→INT16 | 122857 | 1178.460 | 1179.360 | 592.122 | 603.725 |
| Embedding INT4→INT16 | 122857 | 1041.396 | 1039.380 | 1038.376 | 1040.614 |
| PLE INT4→INT16 | 122857 | 6052.702 | 6050.246 | 6041.366 | 6099.906 |

同一模式下连续与随机访问的最大差异约 3%；这是当前 host、warm page-cache 的结果，
不能外推为 cold-cache 或设备性能结论。原始结果位于
`verify_logs/gemma4_embedding_lut_x86_token200_20261026/`。

## 资源采样汇总

配置：独立进程、`token_count=200`、连续访问、warmup=10、iterations=20、重复 3 次、`--evict-cache`、采样间隔 10 ms。CPU/RSS/PSS 是采样值；`RSS peak`/`PSS peak` 为三次运行中的最大采样峰值，单位 MiB。

| LUT | 词表 | 模式 | init ms 均值 | warm us 均值 | CPU avg % | RSS avg | RSS peak | PSS peak | minor/major faults 均值 |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| Embedding INT8→INT16 | 262144 | no-prefetch | 0.013 | 200.765 | 51.9 | 3.28 | 4.34 | 1.31 | 6/4 |
| Embedding INT8→INT16 | 262144 | prefetch | 1759.057 | 103.849 | 7.7 | 214.77 | 388.00 | 385.06 | 6147/3073 |
| PLE INT8→INT16 | 262144 | no-prefetch | 0.020 | 1175.260 | 89.8 | 6.70 | 7.16 | 5.57 | 30/15 |
| PLE INT8→INT16 | 262144 | prefetch | 12180.467 | 594.551 | 6.7 | 1049.64 | 2246.51 | 2243.88 | 35844/17921 |
| Embedding INT4→INT16 | 262144 | no-prefetch | 0.581 | 1040.967 | 74.4 | 3.55 | 4.32 | 1.30 | 5/4 |
| Embedding INT4→INT16 | 262144 | prefetch | 1069.414 | 1042.940 | 8.0 | 124.95 | 218.78 | 217.00 | 3459/1729 |
| PLE INT4→FP16 | 262144 | no-prefetch | 0.642 | 17871.033 | 96.7 | 6.71 | 6.88 | 4.92 | 18/11 |
| PLE INT4→FP16 | 262144 | prefetch | 6441.367 | 17988.433 | 14.2 | 731.85 | 1266.77 | 1263.89 | 20163/10082 |
| Embedding INT8→INT16 | 122857 | no-prefetch | 0.011 | 201.048 | 57.6 | 3.25 | 4.32 | 1.34 | 6/4 |
| Embedding INT8→INT16 | 122857 | prefetch | 711.408 | 106.308 | 9.8 | 100.78 | 183.71 | 180.96 | 2403/1440 |
| PLE INT8→INT16 | 122857 | no-prefetch | 0.016 | 1176.217 | 87.4 | 6.68 | 8.61 | 5.57 | 29/15 |
| PLE INT8→INT16 | 122857 | prefetch | 5653.177 | 591.736 | 7.4 | 556.53 | 1056.50 | 1053.69 | 16799/8399 |
| Embedding INT4→INT16 | 122857 | no-prefetch | 0.576 | 1041.000 | 68.9 | 3.56 | 4.25 | 1.29 | 4/4 |
| Embedding INT4→INT16 | 122857 | prefetch | 451.214 | 1041.577 | 13.6 | 66.14 | 105.35 | 102.23 | 1623/811 |
| PLE INT4→INT16 | 122857 | no-prefetch | 0.595 | 6036.927 | 93.5 | 6.79 | 7.15 | 4.88 | 17/11 |
| PLE INT4→INT16 | 122857 | prefetch | 3007.000 | 6083.480 | 14.6 | 349.08 | 597.07 | 594.39 | 9450/4725 |

完整原始数据：

- `verify_logs/gemma4_embedding_lut_x86_resource_20261026/no_prefetch/`
- `verify_logs/gemma4_embedding_lut_x86_resource_20261026/prefetch/`

## 7 档 token 总读取耗时

新增测试 token 数：64、128、256、512、1024、2048、4096。表中数值是一次
`lookupEmbedding()` 读完该行全部 token 的平均耗时，单位 us；每个值为 3 次
重复的 sequential 平均值。每条原始记录同时包含 `all_tokens_read_us_total`，即
20 次 iterations 累计读完全部 token 的总耗时。

### no-prefetch

| LUT | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 |
|---|---:|---:|---:|---:|---:|---:|---:|
| full Embedding INT8→INT16 | 64.4 | 129.8 | 259.3 | 518.3 | 1036.6 | 2084.6 | 4156.6 |
| full PLE INT8→INT16 | 418.5 | 753.4 | 1504.7 | 3004.6 | 6023.1 | 12090.0 | 24315.3 |
| full Embedding INT4→INT16 | 333.2 | 664.9 | 1332.4 | 2660.6 | 5309.8 | 10642.9 | 21295.5 |
| full PLE INT4→FP16 | 5694.0 | 11422.2 | 22888.1 | 45812.8 | 91719.0 | 184259.7 | 369119.7 |
| pruned Embedding INT8→INT16 | 64.8 | 129.7 | 259.2 | 518.7 | 1038.7 | 2077.1 | 4153.0 |
| pruned PLE INT8→INT16 | 375.3 | 752.1 | 1508.8 | 3012.1 | 6016.1 | 12050.1 | 24350.5 |
| pruned Embedding INT4→INT16 | 392.5 | 665.5 | 1331.1 | 2656.4 | 5314.6 | 10626.9 | 21323.3 |
| pruned PLE INT4→INT16 | 1931.5 | 3864.9 | 7729.4 | 15458.8 | 30930.4 | 61947.2 | 123811.7 |

### prefetch

| LUT | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 |
|---|---:|---:|---:|---:|---:|---:|---:|
| full Embedding INT8→INT16 | 33.3 | 78.7 | 133.7 | 265.8 | 532.0 | 1063.2 | 2128.6 |
| full PLE INT8→INT16 | 189.3 | 378.1 | 761.3 | 1515.1 | 3036.3 | 6102.4 | 12532.6 |
| full Embedding INT4→INT16 | 333.5 | 664.6 | 1330.8 | 2655.5 | 5622.3 | 10634.9 | 21278.3 |
| full PLE INT4→FP16 | 5699.2 | 11496.3 | 23026.1 | 45974.7 | 92206.1 | 184978.3 | 371204.0 |
| pruned Embedding INT8→INT16 | 33.1 | 66.1 | 132.4 | 266.1 | 531.1 | 1070.1 | 2131.8 |
| pruned PLE INT8→INT16 | 189.4 | 378.6 | 756.5 | 1540.0 | 3033.3 | 6130.7 | 12587.7 |
| pruned Embedding INT4→INT16 | 334.2 | 665.9 | 1329.9 | 2659.8 | 5314.1 | 10632.6 | 21264.9 |
| pruned PLE INT4→INT16 | 1930.8 | 3868.5 | 7725.6 | 15464.4 | 30910.5 | 61867.5 | 123774.3 |

结果目录：

- `verify_logs/gemma4_embedding_lut_x86_tokens_20261027/no_prefetch/`：336 runs，包含 sequential/random。
- `verify_logs/gemma4_embedding_lut_x86_tokens_20261027/prefetch/`：168 runs，包含 sequential。

## 7 档 token CPU/内存采样

资源采样配置与 token 延迟矩阵一致，采样间隔 10 ms；下表为 full vocabulary、sequential、3 次重复的平均 CPU 和三次中的 RSS/PSS 峰值。单位：CPU 为百分比，内存为 MiB。

### no-prefetch

| LUT | token | CPU avg | RSS peak | PSS peak |
|---|---:|---:|---:|---:|
| Embedding INT8→INT16 | 64/128/256/512/1024/2048/4096 | 31.0/31.1/70.1/81.8/87.6/93.4/96.4 | 3.5/3.8/4.1/4.9/6.4/11.8/21.4 | 0.7/1.0/1.6/2.7/5.0/9.5/18.5 |
| PLE INT8→INT16 | 64/128/256/512/1024/2048/4096 | 77.7/85.6/93.3/95.4/98.3/99.0/99.5 | 5.1/5.6/8.6/15.0/26.9/55.8/106.5 | 2.1/3.7/7.0/13.6/26.8/53.0/105.5 |
| Embedding INT4→INT16 | 64/128/256/512/1024/2048/4096 | 15.5/70.1/80.1/86.2/94.2/96.9/98.3 | 3.6/3.8/4.0/4.8/6.4/9.4/17.4 | 0.8/1.0/1.5/2.4/4.4/8.2/16.0 |
| PLE INT4→FP16 | 64/128/256/512/1024/2048/4096 | 93.6/95.6/97.7/98.9/99.4/99.7/99.9 | 4.4/5.6/8.6/13.9/22.7/47.6/90.0 | 2.0/3.3/6.1/11.7/22.9/45.4/90.3 |

### prefetch

| LUT | token | CPU avg | RSS peak | PSS peak |
|---|---:|---:|---:|---:|
| Embedding INT8→INT16 | 64/128/256/512/1024/2048/4096 | 39.8/79.8/68.5/82.9/90.5/94.7/96.9 | 385.9/387.2/385.7/386.8/388.9/391.3/396.9 | 384.7/384.8/385.2/386.0/387.4/390.5/396.5 |
| PLE INT8→INT16 | 64/128/256/512/1024/2048/4096 | 151.3/143.4/137.2/119.0/107.7/107.6/100.9 | 2241.0/2245.2/2244.3/2250.7/2258.5/2276.1/2313.4 | 2241.6/2242.7/2244.9/2249.2/2258.0/2275.5/2310.5 |
| Embedding INT4→INT16 | 64/128/256/512/1024/2048/4096 | 40.5/56.9/71.8/85.7/93.3/96.7/98.3 | 216.8/218.1/216.6/217.7/219.9/222.1/227.7 | 216.6/216.8/217.2/217.9/219.4/222.5/228.5 |
| PLE INT4→FP16 | 64/128/256/512/1024/2048/4096 | 101.3/99.4/99.6/99.1/99.4/100.8/101.0 | 1263.4/1263.4/1266.7/1272.0/1280.9/1298.5/1331.6 | 1261.6/1262.7/1264.8/1269.2/1278.0/1295.5/1330.5 |

资源原始结果：

- `verify_logs/gemma4_embedding_lut_x86_tokens_resource_20261027/no_prefetch/`：168 runs，全部 PASS。
- `verify_logs/gemma4_embedding_lut_x86_tokens_resource_20261027/prefetch/`：168 runs，全部 PASS。

裁剪词表、完整 CPU 峰值、VmHWM、VmSize 和缺页数据均保存在上述目录的 `comparison.csv` 与各 case 的 `result.json` 中。

## 解释与限制

1. prefetch 的 RSS/PSS 不是 LUT 文件大小的替代指标，而是该进程采样到的 resident/proportional resident 页面；文件映射、共享页和采样时机都会影响数值。
2. no-prefetch 进程很短，10 ms 采样可能少于完整初始化窗口，因此其峰值只能解释为“采样到的峰值”，不能声称捕获了所有瞬时峰值。
3. CPU 峰值受短进程和 `/proc` 采样粒度影响，个别样本可出现超过单核 100% 的量化值；最终决策应优先看 CPU 平均值、初始化耗时和 RSS/PSS。
4. `POSIX_FADV_DONTNEED` 返回成功表示驱逐请求被接受，不保证系统完全清空所有共享页，因此 cold-cache 结果需在同一主机协议下比较。
5. 本报告没有覆盖 TFLite/MDLA 编译、Android runtime 或手机端性能；设备结论必须另行执行端到端 benchmark。

## 可复现实验入口

- 正确性：`scripts/gemma4_embedding_benchmark/verify_correctness.py`
- 性能/资源：`scripts/gemma4_embedding_benchmark/run_lut_benchmark.py`
- [验证器设计](gemma4-embedding-ple-lut-x86-benchmark-design-20261026.md)
- [复现命令](gemma4-embedding-ple-lut-x86-command-log-20261026.md)
