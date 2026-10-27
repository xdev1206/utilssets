# Gemma4 裁剪模型 PTQ 与可选优化参数（2026-10-16）

## 当前实验

- 模型：`work/gemma-4-E2B-it_embedding-pruning`，词表 122857；PTQ staging 使用对应的 Gecko4 MTK `config.json`。
- 配置：`work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_20261016.json`，保持 `sym4W_sym16A`、embedding `int8`、residual `sym16`、cache `int8`。
- 校准集：`work/gemma4_e2b_it/calibration_datasets/gemma-4-E2B-it_2048`。
- 正式 Hessian PTQ 已成功：隔离使用 `mtk_converter 10.3.0 + protobuf 3.20.3`，耗时约 2:36:54，RAM 峰值 46.34 GB、VRAM 峰值 32.96 GB。日志：`logs_ptq_w4a16_embint8_pruned_hessian_20261016.log`。
- NP8 ctx4096 的 fix-shape、surgery、cut、MDLA 编译均已成功；PROM/GEN shared DLA 和 SHA 已生成。资产目录：`assets/assets_gemma4_hessian_pruned_np8_ctx4096_20261016`。
- 由于词表已裁剪为 122857，设备端不能使用原始 262144 词的 `tokenizer_gemma4.model`。已基于 release 工具转换为 `vocab.txt + merges.txt + added_tokens.yaml`，修正版资产目录为 `assets/assets_gemma4_hessian_pruned_np8_ctx4096_hf_tokenizer_20261016`，YAML `vocabSize` 已改为 122857。
- 2026-10-19 重新执行 NP8 ctx4096 fix-shape、surgery、cut、MDLA，fix-shape 日志明确导出 `embedding_int8.bin`/`ple_int8.bin`。ncc I/O 检查显示 `input_embeds_0` 为 `kTfLiteInt16`；之前 `detect_io_types.sh` 未匹配带后缀的输入名而错误回退 FP16，已修正匹配规则。
- 真正的 INT8 embedding 资产已打包到 `assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019`，YAML 使用 `modelInputType: INT16`、`tokenEmbPath: embedding_int8.bin`、`pleEmbPath: ple_int8.bin`。两份 bin 与 fix-shape 输出 SHA256 一致。
- tokenizer 首次设备运行的 `stoi: no conversion` 已定位为旧转换脚本直接写入原始换行 token，已改用 v1.11.1 脚本的 U+FFFF/U+FFFE 占位符格式；`vocab.txt` 共 122857 条，ID 行全部可解析。
- 2026-10-19 设备验证继续进入模型初始化，但旧 `llm_cmdline_tool-gemma4_release` 将 `embedding_int8.bin` 按 `modelInputType: INT16` 解释，导致 embedding 推导词表为 61428，并在 PLE 校验时报错：`PLE file size ... is not divisible by vocabSize (61428) * typeSize (2)`。因此当前资产是真正的 INT8 LUT，但该旧 main 不支持 INT8 LUT 文件类型；不能把这次失败误判为 bin 损坏。
- 已在 `llm_cmdline_tool-gemma4_release` runtime 中加入 `embeddingFileType: INT8` 配置解析，以及 INT8 LUT 到 INT16 graph input 的符号扩展转换；使用 NDK r29 重编译 `libmtk_llm.so`/`main` 后，设备端已完成真实 INT8 LUT 的模型初始化和推理。
- 设备 benchmark（TECNO CO9m / MT6899 / NP8 / ctx4096）结果：初始化约 0.82--0.84 s，prefill 2286--2346 tok/s，decode 29.49--30.72 tok/s；进程 RSS 峰值约 1.98--2.09 GiB，HWM 约 2.10 GiB，进程 CPU 时间约 3.7--3.9 s。详细日志位于项目 `verify_logs/device_int8_hessian_20261019/`。
- 推理链路已返回 rc=0，但当前输出出现大量乱码/异常 token，说明 INT8 LUT 的数值尺度或 tokenizer/量化对齐仍需单独修复；benchmark 数值可用，质量结论不能判定为通过。

## 资产大小与 benchmark 汇总

最终资产目录：`assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019`。

| 类别 | 文件 | 大小 |
|---|---|---:|
| PROM DLA | `ctx4096_256t4096c_0_opt_sharedkv_shared.dla` | 3,014,687 B（约 3.0 MB） |
| GEN DLA | `ctx4096_1t4096c_0_shared.dla` | 771,610,903 B（约 771.6 MB） |
| DLA 合计 | — | 774,625,590 B（约 774.6 MB） |
| Token embedding | `embedding_int8.bin` | 188,708,352 B（约 188.7 MB） |
| PLE | `ple_int8.bin` | 1,100,798,720 B（约 1.10 GB） |
| 共享权重 | `gemma-4-E2B-it_sha_ctx4096.bin` | 295,798,784 B（约 295.8 MB） |

上述主要模型文件合计约 2.03 GB；加上 tokenizer、YAML 和词表等文件，资产目录约 2.03 GB。

设备 benchmark 使用 3 条 prompt（t0/t3/t4）：初始化 0.8196–0.8407 s，Prefill 2286.4–2346.05 tok/s，Decode 29.4894–30.7179 tok/s，进程 RSS 峰值 1978.8–2086.7 MiB，HWM 峰值约 2098.6–2099.4 MiB，进程 CPU 时间 3.71–3.93 s，全部 `rc=0`。逐条日志和机器汇总见 `verify_logs/device_int8_hessian_20261019/benchmark_summary.json`。

## 2026-10-27 中间产物保留情况

Hessian PTQ 的工作区中间图与校准缓存已按中间产物清理记录删除；下列日志、最终 INT8 资产和设备结果仍保留：

- PTQ 配置：`work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_20261016.json`；模型配置：`work/gemma4_e2b_it/gemma-4-E2B-it_embedding-pruning_ptq/config.json`。
- PTQ 模型 staging 目录 `work/gemma4_e2b_it/gemma-4-E2B-it_embedding-pruning_ptq/` 仍保留模型权重和 tokenizer 文件，但日志所引用的 `config.json` 当前已不存在。
- Hessian PTQ 日志：`logs/ptq/gemma4_embint8_pruned_20261016/logs_ptq_w4a16_embint8_pruned_hessian_20261016.log`；同目录还保留无 Hessian、converter 10.3 和 legacy 对照日志。
- PTQ 日志记录的输出目录 `work/gemma4_e2b_it/quantized_models_w4a16_embint8_pruned_hessian_20261016/` 目前不存在。
- 校准集 `work/gemma4_e2b_it/calibration_datasets/gemma-4-E2B-it_2048/` 和 fix-shape 中间目录 `work/np8_multictx_hessian_pruned/ctx4096/` 目前不存在。
- 2026-10-16 fix-shape、surgery/cut/MDLA、package 阶段日志仍保留在 `logs/deploy/np8_hessian_pruned_ctx4096/`。这些日志引用已清理的中间目录，package log 中的 `_20261016` 资产目录也不再存在。
- 当前保留的最终 runtime-INT8 包：`assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019/`。它是 2026-10-19 重打包后的资产；对应阶段的全部中间产物和逐阶段日志未全部保留。
- 设备结果保留于 `verify_logs/device_int8_hessian_20261019/`、`verify_logs/device_gemma4_embint8_hessian_v3_benchmark_20261023_1430_m128/` 和 `verify_logs/device_embint8_pleint8_hessian_graphint16_np8_ctx4096_20261025_150ms/`。

另有配置快照 `work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_hessian_int16_20261023.json`，但现存 PTQ 日志没有引用该文件名，不能据此确认以上 10-16 PTQ 产物由它生成。当前也没有找到与这些设备量化输出逐条配对的 FP32 对照报告。

## CLI 支持的参数与选择

`mtk_ptq_llm -h` 在当前 SDK 中支持：

- 量化/校准：`--opt`（MLKits 精度 JSON）、`-p/--precision-config`（legacy）、`-m/--calibration-method`、`-c/--act-clip-range`、`--get-emb-minmax-from-cal-data`。
- 权重优化：`-w hessian|gradient`；默认不做，通常先用默认 per-channel 基线，再单独比较 Hessian/Gradient。
- 权重量化粒度：默认 per-channel；`--per-tensor-weight-quant` 只作为体积/兼容性对照，不作为质量优先方案。
- 激活精度优化：`--aopt {None,0,1,2,3,4}`，必须同时提供 `--opt`；需要逐项实测，不能仅凭编号判断优劣。
- 校准方法实际值：`Average`、`Constant`、`EMA`、`Histogram`、`Overall`、`Percentile`。当前基线是 `Overall`。
- 图/导出：`--format {tflite,mlir}`、`--np-compat {7,8,9,10}`、`--use-single-bmm-attention`、`--use-opt-separate-bmm`、`--pad-lm-head`。
- VSQ：`--vsq-encoder`、`--vsq-llm`及向量大小；当前 TFLite 流程不适用，且 VSQ 仅支持 MLIR，应排除。
- 调试/高级参数：`--dump-qparams`、`--load-qparams`、`--load-qparams-folder-name`、`--fc-input-qparams-dir`、`--evaluation-dataset`、`--partial`、`--debug`、`--extra-converter-options`、`--ana-folder`、`--cat-metadata`。

## 当前建议顺序

1. 先恢复与 `mlkits 10.4.9` 配套的完整 converter/protobuf 环境，重跑当前 JSON + `Overall` + per-channel。
2. 基线成功后，一次只改变一个变量：先比较 `Percentile`，再比较 `-w gradient`、`-w hessian`，最后尝试 `--aopt 1/2`。
3. `--np-compat 8` 是导出兼容目标，不是精度优化参数；手机目标 NP8 时在最终导出阶段固定指定。
4. `--per-tensor-weight-quant`、VSQ、`--act-clip-range` 不应在没有对照实验或明确取值时直接用于最终模型。
