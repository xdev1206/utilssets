# Gemma4 Embedding INT8 + no-Hessian + PLE INT16 流程记录

## 目标

全量 `sym4W_sym16A` 权重量化，`embeddings=int8`，不启用 Hessian；保持 PLE 外部逻辑输入 FLOAT32、图内首个 QUANTIZE 后的物理接口 INT16，并以 NP8/MT6899 完成设备产物打包。

## 配置与关键逻辑

- 配置：`configs/gemma4/quant_w4a16_embint8_nohessian_pleint16.json`
- PTQ 将 Embedding/PLE 导出为 INT8 LUT；命令不带 `-w hessian`，日志为
  `Weight optimization: None`。
- `default` 与 `pleInputType` 对应的图边界和 Runtime 语义见
  [PLE activation 精度说明](gemma4-ple-default-activation-precision.md)。

## 已执行命令

```bash
export G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
export G4_WORK_DIR=$PWD/work/gemma4_e2b_it
export G4_PRECISION_JSON_SRC=$PWD/configs/gemma4/quant_w4a16_embint8_nohessian_pleint16.json
export G4_PTQ_NAME=gemma-4-E2B-it_gemma4_precision_config_Overall
export G4_CALIB_JSONL_SRC=$PWD/eval_data/open_prompt_500_20.jsonl
export G4_CALIB_B=264
bash scripts/deploy/gemma4_v2/2_ptq.sh
bash scripts/deploy/gemma4_v2/3_fix_shape.sh

export NP8_SDK=/workspace/xin.xu5/projs/gemma_projs/mtk-npu-llm-deploy/.neuro-pilot/neuropilot-sdk-premium-8.0.11-build20260211/neuron_sdk
export SRC=$G4_WORK_DIR/quantized_models/dynamic_shape/$G4_PTQ_NAME
export OUTROOT=$G4_WORK_DIR/np8_embint8_nohessian_pleint16
export CTXS=4096 STAGES=fix,surgery,cut,mdla,package LUT_TYPE=INT8 NP_COMPAT=8 PLATFORM=MT6899
export ASSETS_NAME=assets_gemma-4-E2B-it_np8_ctx4096_embint8_nohessian_pleint16_20261023
bash scripts/deploy/gemma4_v2/8_multictx_np8.sh 4096
```

## 结果

- PTQ：35 个 decoder layer + tail 全部成功；日志：`work/gemma4_e2b_it/logs/ptq_embint8_nohessian_pleint16_20261023.log`。
- 日志证据：`Default activation precision: int16`、`Embedding input precision: int8`、`Residual path precision: int16`、`Weight optimization: None`。
- fix-shape：`1t4096c`、`256t4096c` 成功；surgery 两张图均 `before_count=177, changed_count=177`；NP8 prompt cut 执行了 `FULLY_CONNECTED v13 -> v11` 兼容处理。
- MDLA prompt/gen 编译、shared DLA 提取和 SHA 导出成功。
- 产物目录：`assets/assets_gemma-4-E2B-it_np8_ctx4096_embint8_nohessian_pleint16_20261023/`
- 文件大小：`embedding_int8.bin` 402,653,184 bytes；`ple_int8.bin` 2,348,810,240 bytes；SHA 295,798,784 bytes。
- YAML：`embeddingFileType=INT8`、`pleFileType=INT8`、`pleInputType=INT16`、`modelInputType=INT16`。
- 设备验证：截至记录时 `adb devices` 为空，尚未执行 push 和手机 benchmark；不能将设备端结果标记为成功。

## 证据文件

- `work/gemma4_e2b_it/logs/fix_shape_embint8_nohessian_pleint16_20261023.log`
- `work/gemma4_e2b_it/logs/np8_embint8_nohessian_pleint16_20261023.log`
- `assets/assets_gemma-4-E2B-it_np8_ctx4096_embint8_nohessian_pleint16_20261023/BUILD_INFO_np8_ctx4096.txt`
- `assets/assets_gemma-4-E2B-it_np8_ctx4096_embint8_nohessian_pleint16_20261023/gemma4_e2b_device_ctx4096.yaml`

## 手机 benchmark（2026-10-23）

命令：

```bash
DEVBASE=/data/local/tmp/llm_cmdtool_g4v2 bash scripts/device/run_gemma4_device.sh \
  --assets assets_gemma-4-E2B-it_np8_ctx4096_embint8_nohessian_pleint16_20261023 \
  --yaml gemma4_e2b_device_ctx4096.yaml \
  --prompts verify_logs/screen_baselines/device_prompts_v3_64_4096 \
  --out verify_logs/device_embint8_nohessian_pleint16_np8_ctx4096_20261023 \
  -m 128 --extra "--first-token-with-gen-model"
```

| prompt | input tokens | output tokens | prefill tok/s | decode tok/s | CPU avg/peak % | RSS peak MiB | DMA-BUF peak MiB | conservative total peak MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| t0 | 64 | 66 | 884.07 | 24.9191 | 59.72/191.14 | 874.11 | 1363.94 | 2238.05 |
| t1 | 128 | 98 | 903.46 | 24.7582 | 39.23/224.66 | 631.98 | 1363.94 | 1995.91 |
| t2 | 256 | 106 | 1122.71 | 24.4903 | 35.98/98.09 | 331.04 | 1363.94 | 1694.98 |
| t3 | 512 | 87 | 1710.36 | 24.9102 | 38.56/233.33 | 948.33 | 1363.94 | 2312.27 |
| t4 | 1024 | 100 | 1864.20 | 24.4250 | 43.29/306.59 | 151.41 | 1363.94 | 1515.35 |
| t5 | 2048 | 69 | 2078.21 | 24.5956 | 45.97/214.67 | 151.23 | 1363.94 | 1515.16 |
| t6 | 4096 | 11 | 2134.51 | 24.3416 | 56.63/220.11 | 283.70 | 460.35 | 744.04 |

运行层面 7/7 完成、无崩溃；日志均确认 `TokenEmbeddingLut lookup: file=INT8 output=INT16`。但生成文本均为乱码/控制 token，按语义质量门禁判定 FAIL；`summarize_benchmark.py` 的 `PASS/runtime` 仅表示进程未崩溃，不代表模型质量通过。详细数据：`verify_logs/device_embint8_nohessian_pleint16_np8_ctx4096_20261023/benchmark.md`。

## x86 oracle 归因

同一 PTQ/fix-shape 图运行 `4b_oracle_quantized.sh` 后，x86 quantized oracle 能生成正常的日文、英文、德文和摘要文本；设备端才出现乱码。因此当前 FAIL 不能归因于 no-Hessian PTQ 精度，优先排查设备侧 NP8 DLA/runtime 对 INT16 PLE 输入边界的解释、量化 scale/zero-point 和编译后输入 tensor 映射。设备端日志已证明 LUT 解码本身为 `INT8 → INT16`，但这不等于 DLA 接收到的 INT16 数值语义与 x86 图一致。

补充对照：历史 Embedding INT8 + Hessian 的设备 benchmark（`verify_logs/device_gemma4_embint8_hessian_v3_benchmark_20261023_1430_m128/`）同样出现乱码；其 `plepath` YAML 和 runtime 日志也是 `pleFileType=INT8`、`pleInputType=INT16`、`TokenEmbeddingLut INT8 → INT16`。因此这属于已有设备侧问题，不是本次 no-Hessian 或配置修改单独引入。

2026-10-25 的历史 INT8→INT16 输入链路复核与图边界证据已归并到
[PLE activation 精度说明](gemma4-ple-default-activation-precision.md)，本篇保留本次运行的
命令、产物和设备质量结果。
