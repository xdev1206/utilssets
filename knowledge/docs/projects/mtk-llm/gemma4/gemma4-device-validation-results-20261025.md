# Gemma4 端侧验证与比较（2026-10-25）

本文汇总 2026-10-25 的 INT4/INT16、INT8 no-Hessian 和裁剪 Hessian 资产设备测试。
所有 `rc=0` 结果只证明进程完成执行；文中各项语义质量门禁均单独判定，不以吞吐或无崩溃代替精度验收。

## INT4/INT16 端侧验证

### 2026-10-25 group64 + Runtime INT16 全流程实测

目标配置为 `configs/gemma4/quant_w4a16_embint4_pleint4_group64_ptq.json`：Embedding/PLE
逻辑 INT4、PTQ INT8 容器、group64、`default=sym4W_sym16A`、Runtime/DLA INT16、
无 Hessian。实际执行命令链为：

```bash
G4_PLE_HISTORICAL_INT16=1 bash scripts/deploy/gemma4_v2/2_ptq.sh
STAGES=fix,surgery,cut,mdla bash scripts/deploy/gemma4_v2/8_multictx_np8.sh 4096
bash scripts/deploy/gemma4_v2/3d_export_g4luti4.sh
STAGES=package bash scripts/deploy/gemma4_v2/8_multictx_np8.sh 4096 package
ADB_PORT=15037 DEVBASE=/data/local/tmp/llm_cmdtool_g4v2 \
  bash scripts/device/push_cmdtool_gemma4_v2.sh --tool --assets \
  assets/assets_gemma-4-E2B-it_np8_ctx4096_embint4_pleint4_historical_int16_20261025
ADB_PORT=15037 DEVBASE=/data/local/tmp/llm_cmdtool_g4v2 \
  bash scripts/device/run_gemma4_device.sh --assets \
  assets/assets_gemma-4-E2B-it_np8_ctx4096_embint4_pleint4_historical_int16_20261025 \
  --yaml gemma4_e2b_device_ctx4096.yaml \
  --prompts verify_logs/screen_baselines/device_prompts_v3_64_4096 \
  --out verify_logs/device_embint4_pleint4_group64_historical_int16_np8_ctx4096_20261025 \
  -m 128 --extra "--first-token-with-gen-model"
```

PTQ 36/36 成功，fix/surgery/cut/MDLA 均成功，4 个 DLA/共享权重和两个 G4LUTI4
文件已打包并推送；设备端 t0–t6 为 7/7 `rc=0`、无 SIGSEGV。但输出出现空回复、
重复 token 和乱码，因此质量门禁为 **FAIL**，不能把本次吞吐视作有效模型质量结果。
完整原始日志和汇总位于：
`verify_logs/device_embint4_pleint4_group64_historical_int16_np8_ctx4096_20261025/`。

| prompt | input tokens | output tokens | prefill tok/s | decode tok/s | RSS peak MiB | DMA-BUF peak MiB | 保守总和 MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| t0 | 64 | 3 | 665.95 | 15.9357 | 881.09 | 1319.09 | 2200.18 |
| t1 | 128 | 1 | 659.39 | 19.9363 | 206.25 | 195.56 | 401.81 |
| t2 | 256 | 1 | 824.69 | 20.5489 | 363.74 | 195.56 | 559.30 |
| t3 | 512 | 128 | 1313.06 | 24.9991 | 218.91 | 1412.77 | 1631.68 |
| t4 | 1024 | 3 | 1267.08 | 20.3205 | 248.31 | 195.56 | 443.87 |
| t5 | 2048 | 6 | 1420.67 | 24.7977 | 249.46 | 1412.77 | 1662.22 |
| t6 | 4096 | 5 | 1455.64 | 24.7166 | 289.33 | 1408.77 | 1698.09 |

RSS 与 DMA-BUF 的统计来自约 300 ms 主采样；PSS/内存交叉采样约 1.2 s；本轮
NeuroPilot 专用计数器不可用，保守总和为 RSS peak + DMA-BUF peak。下一步必须先做
INT4 LUT 解码值、group scale、图内 `FLOAT32 → QUANTIZE → INT16` scale 的
bit-exact 对照，并回归 Embedding INT8 控制包，再重新编译和测端。

### 150 ms 采样复测

`scripts/device/run_gemma4_device.sh` 的主采样和 DMA-BUF 交叉采样循环均从
`sleep 0.3` 改为 `sleep 0.15`。由于 `/proc`、`smaps` 和设备扫描开销，实际主采样
间隔约 199–267 ms，平均约 214–223 ms；交叉采样仍每 4 次主采样执行。复测目录为：
`verify_logs/device_embint4_pleint4_group64_historical_int16_np8_ctx4096_20261025_150ms/`。

复测 t0–t6 仍为 7/7 正常退出、无 SIGSEGV，但语义输出仍 FAIL。总体 CPU 峰值
358.97%，RSS 峰值 586.10 MiB，DMA-BUF 峰值 1412.77 MiB，保守总和峰值
1961.29 MiB；详细结果以该目录下的 `benchmark_summary.md`、`benchmark_summary.json`
和 `resource_summary.md` 为准。

最新完整包：

```text
assets/assets_gemma-4-E2B-it_np8_ctx4096_embint4_pleint4_int16_nohessian_20261025/
```

G4LUTI4 文件：

| 文件 | rows×cols | group | 输出 | 大小 |
|---|---:|---:|---|---:|
| `embedding.g4luti4` | 262144×1536 | 64 | INT16 | 226,492,512 B |
| `ple.g4luti4` | 262144×8960 | 64 | INT16 | 1,321,205,856 B |

大小公式为 `elements×0.5 + ceil(elements/group_size)×4 + 96`，与实际文件一致；
因此物理存储确实是 packed INT4 + FP32 group scales + 96-byte header。

### Embedding/PLE INT8 + no-Hessian 150 ms benchmark

复用已存在的资产 `assets/assets_gemma-4-E2B-it_np8_ctx4096_embint8_nohessian_pleint16_20261023/`，
其文件类型为 `embeddingFileType=INT8`、`pleFileType=INT8`，图/runtime 物理输入为
`pleInputType=INT16`。使用 t0–t6、`max_new_tokens=128` 和 150 ms 采样重新测试：
7/7 正常退出、无 SIGSEGV，但输出仍含乱码、控制 token 和大量空白，语义质量 FAIL。
结果目录：`verify_logs/device_embint8_nohessian_pleint16_np8_ctx4096_20261025_150ms/`。

| prompt | input | output | prefill tok/s | decode tok/s | RSS peak MiB | DMA-BUF peak MiB | 总和 MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| t0 | 64 | 64 | 715.67 | 24.3824 | 966.41 | 1408.77 | 2375.18 |
| t1 | 128 | 98 | 814.89 | 24.3975 | 463.16 | 1412.77 | 1875.92 |
| t2 | 256 | 106 | 1039.11 | 24.1001 | 728.02 | 1412.77 | 2140.79 |
| t3 | 512 | 89 | 1546.29 | 24.6436 | 563.62 | 1412.77 | 1976.38 |
| t4 | 1024 | 98 | 1514.34 | 24.2431 | 534.07 | 1412.77 | 1946.84 |
| t5 | 2048 | 71 | 2039.34 | 24.3326 | 528.17 | 1412.77 | 1940.94 |
| t6 | 4096 | 11 | 2046.83 | 24.5127 | 555.32 | 1344.50 | 1899.82 |

总体 CPU 平均/峰值为 54.12%/329.00%，RSS 峰值 966.41 MiB，DMA-BUF 峰值
1412.77 MiB，保守总和峰值 2375.18 MiB；NeuroPilot 专用计数器不可用。

### 独立裁剪 Hessian DLA + Embedding/PLE INT4 group64 资产

已基于裁剪模型 `/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it_embedding-pruning/model.safetensors`
的两个 BF16 tensor 生成独立 G4LUTI4 文件，并复用 Hessian INT8 版本的 NP8 DLA：

```text
assets/assets_gemma4_hessian_pruned_embint4_group64_np8_ctx4096_int16_20261025/
```

| 文件 | rows×cols | group | 输出类型 | 大小 |
|---|---:|---:|---|---:|
| `embedding.g4luti4` | 122857×1536 | 64 | INT16 | 106,148,544 B |
| `ple.g4luti4` | 122857×8960 | 64 | INT16 | 619,199,376 B |

YAML 为 `gemma4_e2b_device_ctx4096_int4_group64.yaml`，使用旧裁剪 tokenizer，
`vocabSize=122857`、`embeddingFileType=INT4`、`pleFileType=INT4`、
`pleInputType=INT16`。两份 G4LUTI4 的 Header、group64、scale section、packed
data section 已由 `lut_format.read_lut()` 校验通过。该资产目前仅完成 host 生成和
结构验证，设备 push/benchmark 尚未执行。

该裁剪词表 INT4 assets 目录完整文件清单如下：

| 文件 | 大小 |
|---|---:|
| `BUILD_INFO.txt` | 1,224 B |
| `added_tokens.yaml` | 350 B |
| `ctx4096_1t4096c_0_shared.dla` | 771,610,903 B（735.91 MiB） |
| `ctx4096_256t4096c_0_opt_sharedkv_shared.dla` | 3,014,687 B（2.88 MiB） |
| `embedding.g4luti4` | 106,148,544 B（101.23 MiB） |
| `ple.g4luti4` | 619,199,376 B（590.93 MiB） |
| `gemma-4-E2B-it_sha_ctx4096.bin` | 295,798,784 B（282.10 MiB） |
| `gemma4_e2b_device_ctx4096_int4_group64.yaml` | 4,248 B |
| `merges.txt` | 3,076,747 B（2.93 MiB） |
| `tokenizer.json` | 7,890,167 B（7.52 MiB） |
| `vocab.txt` | 1,809,224 B（1.73 MiB） |

目录文件总大小为 `1,808,554,584 B`（约 `1.68 GiB`，`1.81 GB`）。设备目标目录为：
`/data/local/tmp/llm_cmdtool_g4v2/assets_gemma4_hessian_pruned_embint4_group64_np8_ctx4096_int16_20261025/`。

### Embedding/PLE INT8 + Hessian + graph INT16 benchmark

复用 `assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019/` 的
`gemma4_e2b_device_ctx4096_plepath.yaml`，配置为 `embeddingFileType=INT8`、
`pleFileType=INT8`、`pleInputType=INT16`。使用 t0–t6、`max_new_tokens=128` 和
150 ms 采样，7/7 正常退出、无 SIGSEGV，但输出仍为乱码/控制 token，语义质量 FAIL。
结果目录：`verify_logs/device_embint8_pleint8_hessian_graphint16_np8_ctx4096_20261025_150ms/`。

注意：该历史 Hessian 资产 tokenizer 词表为 122857，故实际输入 token 为
63/127/255/511/1023/2047/4095，而不是新 tokenizer 的 64/128/256/512/1024/2048/4096。

| prompt | input | output | prefill tok/s | decode tok/s | RSS peak MiB | DMA-BUF peak MiB | 总和 MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| t0 | 63 | 132 | 820.60 | 25.9709 | 829.62 | 1309.36 | 2138.99 |
| t1 | 127 | 126 | 1032.60 | 27.0310 | 606.38 | 1305.36 | 1911.74 |
| t2 | 255 | 7 | 1219.45 | 21.8007 | 559.88 | 1241.10 | 1800.98 |
| t3 | 511 | 1 | 1933.38 | 21.1794 | 559.27 | 1305.36 | 1864.63 |
| t4 | 1023 | 124 | 1883.47 | 27.1715 | 578.17 | 1305.36 | 1883.53 |
| t5 | 2047 | 127 | 1832.99 | 22.5273 | 513.73 | 1309.36 | 1823.09 |
| t6 | 4095 | 129 | 1817.60 | 22.9712 | 547.71 | 1309.36 | 1857.08 |

### 独立裁剪 Hessian DLA + Embedding/PLE INT4 group64 完整 benchmark

资产目录：`assets/assets_gemma4_hessian_pruned_embint4_group64_np8_ctx4096_int16_20261025/`。
Embedding/PLE 为 G4LUTI4、group64、Runtime INT16；DLA 复用裁剪 Hessian INT8 版本。
使用 t0–t6、`max_new_tokens=128`、150 ms 采样，7/7 正常退出、无 SIGSEGV，但
7/7 输出均为乱码/控制 token，语义质量 FAIL。

结果目录：`verify_logs/device_hessian_pruned_embint4_group64_graphint16_np8_ctx4096_20261025_150ms/`。

| prompt | input | output | prefill tok/s | decode tok/s | CPU avg/peak % | RSS peak MiB | PSS peak MiB | VmHWM MiB | DMA-BUF peak MiB | 总和 peak MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| t0 | 63 | 131 | 768.24 | 25.6992 | 64.67/226.89 | 891.03 | 741.28 | 897.61 | 1309.54 | 2200.57 |
| t1 | 127 | 127 | 795.57 | 26.2851 | 52.99/215.96 | 520.79 | 146.74 | 898.37 | 1305.54 | 1826.33 |
| t2 | 255 | 130 | 999.76 | 25.9825 | 57.34/302.88 | 441.29 | 160.84 | 897.85 | 1305.54 | 1746.83 |
| t3 | 511 | 131 | 1337.37 | 26.3169 | 66.27/281.11 | 641.95 | 146.27 | 898.41 | 1309.54 | 1951.49 |
| t4 | 1023 | 99 | 1375.87 | 25.7300 | 79.05/293.27 | 463.32 | 148.83 | 898.72 | 1305.54 | 1768.87 |
| t5 | 2047 | 125 | 1274.32 | 22.6929 | 89.84/250.00 | 514.35 | 148.33 | 897.64 | 1309.54 | 1823.89 |
| t6 | 4095 | 131 | 1255.27 | 22.7266 | 94.51/274.42 | 535.52 | 150.75 | 898.00 | 1309.54 | 1845.07 |

总体：CPU 平均 72.10%，CPU 峰值 302.88%，RSS 峰值 891.03 MiB，DMA-BUF 峰值
1309.54 MiB，RSS+DMA-BUF 保守总和峰值 2200.57 MiB。NeuroPilot 专用计数器不可用，
表中 `NeuroPilot=0` 不代表真实占用为零。采样目标为 150 ms，实际主采样约 198–287 ms。
`tokenizer.json` 仅为 host 侧统计所需，设备 YAML 不引用它。

### 四次端侧 benchmark 平均值对比

以下为四次最近同口径 t0–t6 benchmark 的算术平均；内存峰值列为每条 prompt
峰值的平均，不是全局最大值。四组均使用 `max_new_tokens=128` 和约 150 ms 采样目标。

| 实验 | Input tokens | Decode tokens | Prefill tok/s | Decode tok/s | CPU avg % | CPU peak % | RSS avg MiB | RSS peak avg MiB | PSS peak avg MiB | DMA-BUF peak avg MiB | 总峰值 avg MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Embedding/PLE INT8 + no-Hessian | 1161.14 | 76.71 | 1388.07 | 24.3731 | 54.12 | 287.17 | 180.75 | 619.82 | 549.99 | 1402.44 | 2022.27 |
| Embedding/PLE INT8 + Hessian | 1160.14 | 92.29 | 1505.73 | 24.0931 | 87.03 | 261.05 | 168.56 | 599.25 | 219.63 | 1297.90 | 1897.15 |
| Embedding/PLE INT4 group64，历史 DLA | 1161.14 | 21.00 | 1506.69 | 21.7186 | 97.19 | 290.42 | 159.93 | 541.89 | 577.39 | 716.65 | 1258.54 |
| Embedding/PLE INT4 group64，独立 Hessian DLA | 1160.14 | 124.86 | 1115.20 | 25.0619 | 72.10 | 263.50 | 172.05 | 572.61 | 234.72 | 1307.83 | 1880.43 |

### t6 连续 5 次平均值对比

本轮统一只运行 t6（4095/4096 input tokens），每个 benchmark 连续运行 5 次，
均使用 `max_new_tokens=128`。下表是 5 次结果的算术平均。CPU 统计剔除了进程退出
瞬间产生的 `>1000%` 采样异常点；原始采样仍完整保存在各轮目录。

| 实验 | Input tokens | Decode tokens | Prefill tok/s | Decode tok/s | CPU avg % | CPU peak % | RSS avg MiB | RSS peak avg MiB | PSS peak avg MiB | DMA-BUF peak avg MiB | 总峰值 avg MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Embedding/PLE INT8 + no-Hessian（词表 262144） | 4096 | 11 | 2279.69 | 25.2602 | 75.83 | 384.73 | 197.43 | 708.42 | 555.56 | 1011.29 | 1719.71 |
| Embedding/PLE INT8 + Hessian（词表 122857） | 4095 | 129 | 1934.18 | 23.5529 | 94.84 | 319.22 | 164.03 | 574.69 | 136.94 | 1307.94 | 1882.63 |
| Embedding/PLE INT4 group64，历史 DLA（词表 262144） | 4096 | 5 | 1460.68 | 24.9778 | 48.88 | 288.63 | 172.08 | 627.64 | 613.62 | 1408.95 | 2036.59 |
| Embedding/PLE INT4 group64，独立 Hessian DLA（词表 122857） | 4095 | 131 | 1260.23 | 23.4951 | 94.94 | 324.67 | 164.25 | 541.86 | 151.22 | 1307.94 | 1849.80 |

本轮结果目录：`verify_logs/t6x5_<experiment>_r1..r5_20261025_150ms/`。
