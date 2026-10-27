# Gemma4 部署产物索引快照（2026-10-25）

本文汇总截至该日仍需追踪的全词表 INT4 与裁剪词表 INT8 资产；资产各自在对应日期生成，
并非全部于 10-25 构建。全词表 INT8 Hessian 包的唯一清单见
[对应实验记录](gemma4-full-vocab-embint8-hessian-experiment-20261025.md)。设备结果见
[端侧验证报告](gemma4-device-validation-results-20261025.md)，文件布局与尺寸公式见
[G4LUTI4 Runtime 契约](../runtime/gemma4-external-lut-g4luti4-int4.md)。

## 完整词表 Embedding/PLE INT4 assets 文件清单

对应目录：`assets/assets_gemma-4-E2B-it_np8_g4luti4_ctx4096/`；词表为 `262144`，
G4LUTI4 group64，Embedding 为 `INT4→INT16`，PLE 为 `INT4→FP16`。目录内文件如下：

| 文件 | 可读大小（`ls -lh`） | 精确大小 |
|---|---:|---:|
| `BUILD_INFO.txt` | 2.3K | 2,278 B |
| `embedding.g4luti4` | 217M | 226,492,512 B |
| `ple.g4luti4` | 1.3G | 1,321,205,856 B |
| `ctx4096_1t4096c_0_shared.dla` | 840M | 880,025,799 B |
| `ctx4096_256t4096c_0_opt_sharedkv_shared.dla` | 2.9M | 3,014,687 B |
| `gemma-4-E2B-it_sha.bin` | 283M | 295,798,784 B |
| `gemma4_e2b_device.yaml` | 3.8K | 3,812 B |
| `ple.g4luti4.json` | 533 B | 533 B |
| `tokenizer_gemma4.model` | 4.5M | 4,689,016 B |

目录显示为 `2.6G`（`du -sh`）；精确文件总大小为 `2,731,233,550 B`（约 `2.54 GiB`）。设备目标目录为：
`/data/local/tmp/llm_cmdtool_g4v2/assets_gemma-4-E2B-it_np8_g4luti4_ctx4096/`。

### 裁剪词表 Embedding/PLE INT8 assets 文件清单

资产目录：`assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019/`；词表为 `122857`，Embedding/PLE 文件类型为 INT8，`modelInputType=INT16`、`pleInputType=INT16`。

| 文件 | 大小 |
|---|---:|
| `BUILD_INFO_np8_ctx4096.txt` | 882 B |
| `added_tokens.yaml` | 350 B |
| `embedding_int8.bin` | 188,708,352 B（179.99 MiB） |
| `ple_int8.bin` | 1,100,798,720 B（1.03 GiB） |
| `ctx4096_1t4096c_0_shared.dla` | 771,610,903 B（735.91 MiB） |
| `ctx4096_256t4096c_0_opt_sharedkv_shared.dla` | 3,014,687 B（2.88 MiB） |
| `gemma-4-E2B-it_sha_ctx4096.bin` | 295,798,784 B（282.10 MiB） |
| `gemma4_e2b_device_ctx4096.yaml` | 4,075 B |
| `gemma4_e2b_device_ctx4096_plepath.yaml` | 4,114 B |
| `merges.txt` | 3,076,747 B（2.93 MiB） |
| `tokenizer.json` | 7,890,167 B（7.52 MiB） |
| `tokenizer_config.json` | 3,082 B |
| `vocab.txt` | 1,809,224 B（1.73 MiB） |

目录文件总大小为 `2,372,724,183 B`（约 `2.21 GiB`，`2.37 GB`）。设备目标目录为：
`/data/local/tmp/llm_cmdtool_g4v2/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019/`。
