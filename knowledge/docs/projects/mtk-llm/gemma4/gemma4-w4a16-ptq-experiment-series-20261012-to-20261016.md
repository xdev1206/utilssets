# Gemma4 W4A16 PTQ 实验记录（2026-10-12 至 16）

本文按日期记录 W4A16 主干的 x86 和 NP8 尝试。各轮校准数据与运行路径不同，结果分别列出，
不合并为同一精度分数；2026-10-16 的同配置重跑归并在 10-15 结果之后。

## 结论

Gemma-4-E2B-it 使用 0–34 层 `sym4W_sym16A`（W4A16）完成 PTQ、fix-shape 和 x86 oracle 推理，但精度对齐未通过：6 条 screen prompt 中 `2 OK / 3 WEAK / 1 GARBAGE`，平均 ROUGE-L 为 `0.5819`。因此按验证门禁停止，不进入 MDLA 编译或设备测试。

## 配置

配置文件：`work/gemma4_e2b_it/gemma4_quant_w4a16_2048.json`。

```json
{
    "llm": {
        "0-34": {
            "q": "sym4W_sym16A",
            "k": "sym4W_sym16A",
            "v": "sym4W_sym16A",
            "o": "sym4W_sym16A",
            "gate": "sym4W_sym16A",
            "up": "sym4W_sym16A",
            "down": "sym4W_sym16A"
        }
    },
    "tail": "sym4W_sym16A",
    "default": "sym4W_sym16A",
    "softmax": "float",
    "res_path": "sym4W_sym16A",
    "embeddings": "float",
    "logits": "float",
    "cache": "int8"
}
```

校准集：2048 条 prompt，4096 batches。

SDK 日志中的有效解析为：最大权重 bit 为 4，default activation 为 INT16，residual path 为 INT16，embedding 和 logits 为 FP，cache 为 INT8。

## 流程结果

- PTQ：成功，返回码 0，耗时 `2:02:31`
- PTQ RAM Peak：`39.94 GB`
- PTQ VRAM Peak：`36.35 GB`
- fix-shape：成功，返回码 0，耗时 `7:25`
- x86 inference：成功，返回码 0，耗时 `4:18`

产物：

- PTQ：`work/gemma4_e2b_it/quantized_models_w4a16_2048`
- fix-shape：`work/gemma4_e2b_it/quantized_models/quantized_models_w4a16_2048`
- x86 输出：`verify_logs/w4a16_2048_x86_20261015/quant_w4a16_2048_screen6.jsonl`
- 对比汇总：`verify_logs/w4a16_2048_compare_20261015/screen_summary.json`
- 逐条对比：`verify_logs/w4a16_2048_compare_20261015/screen_comparison.md`

## FP32 对比

参考基线：`verify_logs/screen_baselines_it/float_screen6.jsonl`。

| qid | 判定 | ROUGE-L | 首个 mismatch | 现象 |
|---:|---|---:|---:|---|
| 0 | WEAK | 0.5217 | 0 | 日语翻译语义部分偏移 |
| 1 | GARBAGE | 0.2597 | 0 | 韩语选择题答案错误，语言和答案均偏移 |
| 2 | OK | 0.7424 | 6 | 英文续写基本可用 |
| 3 | WEAK | 0.6838 | 4 | 德语翻译部分语义接近但有改写 |
| 4 | OK | 0.8699 | 2 | 摘要基本一致 |
| 5 | WEAK | 0.4140 | 0 | Ollama 更新说明发生明显改写 |

## 后续限制

本结果已经证明图可以在 x86 量化 oracle 运行，但质量未达到进入设备部署的门槛。下一步应优先分析 W4A16 的逐层数值误差、权重/激活量化配置和校准 qparams；不能直接进行 NP8/MDLA 或手机端验证。

## 同配置重跑（2026-10-16）

使用相同配置和 screen6 基线重跑后，逐条判定与上表一致，平均 ROUGE-L 仍为
`0.5819`；首个 mismatch 分别为 `0, 0, 6, 4, 2, 0`。PTQ 36 个图全部生成，耗时
`2:02:05`，RAM/VRAM 峰值为 `39.63/33.43 GB`；fix-shape 生成 `256t4096c` 和
`1t4096c`，耗时 `9:08`。重跑没有改变“不通过精度门禁、不进入设备验证”的结论。

产物与日志：

- PTQ：`work/gemma4_e2b_it/quantized_models_sym4w4a16_2048`
- fix-shape：`work/gemma4_e2b_it/quantized_models/quantized_models_sym4w4a16_2048`
- PTQ 日志：`work/gemma4_e2b_it/logs/ptq_sym4w4a16_20261016.log`
- fix-shape 日志：`work/gemma4_e2b_it/logs/fix_shape_sym4w4a16_20261016.log`
- x86 日志：`work/gemma4_e2b_it/logs/quantinfer_sym4w4a16_20261016.log`
- 对比汇总：`verify_logs/sym4w4a16_compare_20261016/screen_summary.json`

## Earlier 2026-10-12 x86 run

对 `np8_multictx_nosurgery_20261010/ctx4096` 使用 screen6 与 FP32 对比：ROUGE-L 均值
`0.6231`，结果为 `1 GARBAGE / 3 WEAK / 2 OK`。配置使用全投影及 tail
`sym4W_sym16A`、cache INT8。该分数对应此资产和输出目录，不与后续 500 或 2048 条校准集
结果合并。模型目录中的 `.dla` 等非 TFLite 文件需移除后再运行 x86 oracle，否则 SDK
按 `len(os.listdir())` 推断 chunk 数会误报 PROM=4、GEN=5。

同一配置下，score-path surgery 不改变 x86 oracle 结果；早期全投影/tail `sym8W` 的均值
为 `0.9581`，`sym4W+hessian` 为 `0.8964`。这组对照提示 `sym4W` 误差在 35 层中累积，
不能据此把量化质量问题归因于 NP8 cut 或设备 Runtime。

## Fresh500 calibration and NP8 run (2026-10-12)

### Calibration inputs

初始 `open_prompt_500_20.jsonl` 含 20 条文本 prompt；`-b 264` 是生成器最大 batch 数，
每条 prompt 实际生成 2 个 batch，共 40 个 batch，36 个模型 chunk 各保存 40 个 batch。
该配置没有 vision/audio encoder、对应输入文件或校准样本，图像和音频校准数均为 0；
`image_token_ids` 与 `audio_token_ids` 是配置占位信息。

`generate_calibration_prompts.py` 从问答、摘要、翻译、改写、推理/代码五类生成 500 条唯一
JSONL，并使用模型的 `chat_template`；按原 20 条 prompt 的主要语言比例分配英文 325、韩文
100、日文 75。产物为 `work/gemma4_e2b_it/open_prompt_500_fresh.jsonl`。

另一个恢复流程脚本 `merge_fresh500_and_ptq.sh` 会等待校准日志完成，按 batch 偏移 538
合并前缀与恢复段，验证 36 个 chunk 各有 1000 个 batch 后启动独立目录的全量 PTQ；此
1000-batch 合并流程与下述 500-prompt 完成记录是不同执行配置，不应混为一次运行。

### PTQ and device outcome

500-prompt PTQ 生成 36 个 dynamic-shape TFLite 文件，最终 PTQ RAM 峰值 `35.55 GB`。
模型包含 layer 0–35 共 36 个图，其中 layer 0–34 是 decoder layers，layer 35 是 tail；
等待脚本不能只按 35 个 decoder layers 判断完成。

- 环境最初缺少 `ml_dtypes`、`mtk_converter` 和 `scipy`；NP8 shape fix 需要 SDK 匹配的
  `mtk_converter 9.8.0`，量化 x86 推理还需要 `scipy`。
- 脚本切换到 `G4_WORK_DIR` 后，`8_multictx_np8.sh` 的 `SRC`、`OUTROOT` 必须用绝对路径，
  否则相对路径会重复解析。
- NP8 ctx4096 的 fix-shape、score-path surgery、cut、ncc-tflite 8.2.31、extract-shared
  和 packaging 均成功；assets 为 `assets_gemma4_fresh500_np8_ctx4096`。
- x86 quantized 与 FP32 screen6 的 ROUGE-L 为 `0.5106`（`OK=1 / WEAK=3 / GARBAGE=2`）。
  设备与 x86 quantized 输出的 ROUGE-L 为 `0.1757`，6 条均为 `GARBAGE`；设备运行本身
  6/6 `rc=0`，无 NEURON crash。质量门禁未通过。
- 平均 decode 吞吐 `23.95 tok/s`（范围 `22.69–25.55`），prompt-window 吞吐
  `2086 tok/s`（范围 `1283–2517`）。设备命令需传
  `--yaml gemma4_e2b_device_ctx4096.yaml`，资产不使用默认 `gemma4_e2b_device.yaml`。
