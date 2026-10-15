# Gemma4 NP8 PROM cut opcode compatibility

为避免 surgery 后再做一次独立修补，`fix_scorepath.py` 支持 `--np-compat 8`，在
`export_quantized_model` 完成后直接将导出 FlatBuffer 中的 `FULLY_CONNECTED` v13
改为 v11；`8_multictx_np8.sh` 在 NP8 surgery 阶段自动传入该参数。

2026-10-12 对当前 `np8_multictx_nosurgery_20261010/ctx4096` 做 x86 oracle 对拍：先
移除模型目录中的 `.dla` 等非 TFLite 文件（SDK 使用 `len(os.listdir())` 检查 chunk，
否则会误报 PROM=4、GEN=5），再用同一 6 条 screen prompt 与 FP32 对比。结果为
ROUGE-L 均值 0.6231，1 条 GARBAGE、3 条 WEAK、2 条 OK；量化配置是全投影及 tail
`sym4W_sym16A`、cache int8。该结果确认当前量化 x86 已退化，且与设备异常独立：
历史对照中全投影/tail `sym8W` 的 x86 均值为 0.9581，sym4W+hessian 为 0.8964，
说明主要根因是 sym4W 误差在 Gemma4 35 层中累积；score-path surgery 不改变 x86
oracle 结果。

当前校准数据补充：`open_prompt_500_20.jsonl` 有 20 条文本 prompt，日志配置
`-b 264`，实际每条生成 2 个 calibration batch，因此实际处理 40 个 batch；36
个模型 chunk 各保存 40 个 batch。若扩展到 500 条且仍保持每条 2 个 batch，设置
`-b 1000` 没有逻辑问题，但它是最大保存数，需检查最终日志是否达到 1000。当前
Gemma4-E2B-it 配置没有 vision/audio encoder、图像/音频输入文件或对应校准样本，
因此当前图像校准数和 audio 校准数均为 0；`image_token_ids`/`audio_token_ids`
仅是配置占位信息。

新增 `scripts/deploy/gemma4_v2/generate_calibration_prompts.py`：不读取旧的 20 条
prompt，按问答、摘要、翻译、改写、推理/代码五类各生成 100 条，并调用模型自带
`chat_template` 输出 500 条唯一 JSONL。按原 20 条 prompt 的主要语言比例重新分配为
英文 325、韩文 100、日文 75。当前产物为
`work/gemma4_e2b_it/open_prompt_500_fresh.jsonl`，可作为新的文本校准输入。

`merge_fresh500_and_ptq.sh` 会等待恢复校准日志完成，按 batch 偏移 538 合并前缀与
恢复段，验证 36 个 chunk 各有 1000 个 batch 后，自动启动独立目录的全量 PTQ。

Gemma4 E2B IT 的 NP8 验证显示：fix-shape 未 cut PROM 图可被 NP8 `ncc-tflite` 加载，而 `cut_tflite_nanov4.sh --opt-prompt-sharedkv` 生成的 PROM 图在 interpreter 阶段失败。FlatBuffer 对比显示未 cut 图的 builtin `FULLY_CONNECTED` opcode version 为 11，cut 图为 13。将 cut 图中该 opcode version 13 改为 11 后，NP8 成功编译 DLA（PROM DRAM 约 1.5G）。该修复只适用于 NP8，不用于 NP10 设备验证。

## 2026-10-12 fresh500 PTQ / NP8 device run

- Fresh calibration/PTQ completed: 500 prompts, 36 dynamic-shape tflite files (`quantized_models_fresh500`), final PTQ RAM peak 35.55 GB.
- The actual model has layers 0..35, so the expected tflite count is 36; automation waiting for 35 layers must include the final tail graph, while a raw decoder-layer count is 35.
- The specified `mtk_gemma4_env` initially lacked `ml_dtypes`, `mtk_converter`, and `scipy`. NP8 shape fixing requires the SDK-matched `mtk_converter 9.8.0` wheel; quantized x86 inference additionally imports `scipy`.
- `8_multictx_np8.sh` must receive absolute `SRC`/`OUTROOT` paths when it changes into `G4_WORK_DIR`; relative paths are otherwise resolved twice.
- NP8 ctx4096 succeeded with fix-shape, score-path surgery, cut, ncc-tflite 8.2.31, extract-shared, and packaging. Assets: `assets_gemma4_fresh500_np8_ctx4096`.
- x86 quantized vs FP32 screen6: ROUGE-L 0.5106 (`OK=1`, `WEAK=3`, `GARBAGE=2`). Device vs x86 quantized: ROUGE-L 0.1757, all 6 `GARBAGE`; therefore the model is runnable but quality is not acceptable.
- Device run on MT6899/NP8 completed 6/6 with `rc=0` and no NEURON crash. Mean decode throughput was 23.95 tok/s (22.69~25.55); prompt-window throughput was 2086 tok/s (1283~2517). The device runner must pass `--yaml gemma4_e2b_device_ctx4096.yaml`; the package intentionally uses a context-specific YAML name, not the default `gemma4_e2b_device.yaml`.
