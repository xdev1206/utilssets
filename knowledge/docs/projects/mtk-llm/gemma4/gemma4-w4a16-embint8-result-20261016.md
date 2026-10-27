# Gemma4 W4A16 + embedding INT8 PTQ 结果（2026-10-16）

## 配置

配置文件：`work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_20261016.json`

## 复现脚本

复现入口：`scripts/recipe_exp/run_w4a16_embint8_20261016.sh`。脚本激活
`mtk_gemma4_env`，追加 NP10 的 Python 包路径，设置指定的 `CUDA_VISIBLE_DEVICES`，先运行
HF/MTK float 对齐门禁，只有 verdict 为 `PASS` 才继续执行校准集生成、PTQ、fix-shape、x86
量化推理和输出对比。默认用项目已有的 20 条 `open_prompt_500_20.jsonl` 生成新的校准集，
`-b 264` 是校准生成器的最大 batch 上限，不是 2048 条数据。运行示例：

```bash
bash scripts/recipe_exp/run_w4a16_embint8_20261016.sh 6
```

第一个参数是本次分配的 GPU 编号；可选第二个参数指定校准 prompts JSONL，第三个参数指定运行标签。
本脚本使用 20 条校准 prompts，不复用历史 2048 prompts 校准集，因此运行耗时和量化结果不与
2026-10-16 的 `0.6063` 直接等同。脚本为每次运行创建带标签的独立校准集和 PTQ 产物目录，不覆盖历史结果。

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
    "embeddings": "int8",
    "logits": "float",
    "cache": "int8"
}
```

## 流程结果

- PTQ：成功生成 decoder layer 0–34 和 tail layer 35
- PTQ 耗时：`2:03:26`
- PTQ RAM 峰值：`48.30 GB`
- PTQ VRAM 峰值：`37.37 GB`
- fix-shape：成功生成 `256t4096c`、`1t4096c`，耗时 `9:13`
- x86 量化推理：成功，6 条 prompt 全部生成文本

## 与 FP32 基线对比

参考：`verify_logs/screen_baselines_it/float_screen6.jsonl`。

| qid | 判定 | ROUGE-L | 首个 mismatch |
|---:|---|---:|---:|
| 0 | WEAK | 0.6383 | 0 |
| 1 | GARBAGE | 0.2597 | 0 |
| 2 | OK | 0.7424 | 6 |
| 3 | WEAK | 0.6838 | 4 |
| 4 | OK | 0.8327 | 2 |
| 5 | WEAK | 0.4810 | 0 |

汇总：`2 OK / 3 WEAK / 1 GARBAGE`，平均 ROUGE-L `0.6063`。

与上一轮 `embeddings=float` 的全 `sym4W_sym16A` 配置相比：

| 配置 | 平均 ROUGE-L | 判定分布 |
|---|---:|---|
| embeddings=float | 0.5819 | 2 OK / 3 WEAK / 1 GARBAGE |
| embeddings=int8 | 0.6063 | 2 OK / 3 WEAK / 1 GARBAGE |

平均 ROUGE-L 变化：`+0.0244`。由于两次均未通过精度门禁，不能据此认为 embedding INT8 已达到可部署质量；不进入 MDLA 或设备验证。

## 产物

- PTQ：`work/gemma4_e2b_it/quantized_models_w4a16_embint8_20261016`
- fix-shape：`work/gemma4_e2b_it/quantized_models/quantized_models_w4a16_embint8_20261016`
- PTQ 日志：`work/gemma4_e2b_it/logs/ptq_w4a16_embint8_20261016.log`
- fix-shape 日志：`work/gemma4_e2b_it/logs/fix_shape_w4a16_embint8_20261016.log`
- x86 日志：`work/gemma4_e2b_it/logs/quantinfer_w4a16_embint8_20261016.log`
- x86 输出：`verify_logs/w4a16_embint8_x86_20261016/quant_w4a16_embint8_screen6.jsonl`
- 对比汇总：`verify_logs/w4a16_embint8_compare_20261016/screen_summary.json`
- 逐条对比：`verify_logs/w4a16_embint8_compare_20261016/screen_comparison.md`
