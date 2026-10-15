# Gemma4 dynamic_quant + 2048 校准集结果（2026-10-14）

## 结论

在 Gemma-4-E2B-it 上使用 `dynamic_quant` 配置和 2048 条语言均衡校准 prompt，完整 PTQ、fix-shape 及 x86 量化推理均成功。6 条 screen prompt 与 FP32 `-it` 基线对比全部为 `OK`，平均 ROUGE-L 为 `0.9479`，未发现乱码、复读或明显语义退化。

该结果仅代表 x86 量化推理验证通过；尚不等同于 NP8/MDLA 编译和手机端验证通过。

## 配置

校准集：

- 文件：`work/gemma4_e2b_it/open_prompt_2048_langbalanced.jsonl`
- 数量：2048 条，内容不重复
- 语言分布：英语 1229（60.01%）、韩语 468（22.85%）、日语 351（17.14%）
- 相比原 500 条 prompt，英语占比降低约 4.99 个百分点
- 校准 batches：4096，即每条 prompt 使用 2 个 batch

动态量化配置 `work/gemma4_e2b_it/gemma4_quant_dynamic_2048.json`：

```json
{
    "llm": {"0-34": "dynamic_quant"},
    "tail": "dynamic_quant",
    "default": "dynamic_quant",
    "softmax": "float",
    "res_path": "dynamic_quant",
    "embeddings": "dynamic_quant",
    "logits": "float",
    "cache": "int8"
}
```

## 执行产物

- PTQ 原始输出：`work/gemma4_e2b_it/quantized_models_dynamic_2048`
- fix-shape 输出：`work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_2048`
- x86 推理结果：`verify_logs/dynamic_2048_x86_20261014/quant_dynamic_2048_screen6.jsonl`
- 对比汇总：`verify_logs/dynamic_2048_compare_20261014/screen_summary.json`
- 逐条对比：`verify_logs/dynamic_2048_compare_20261014/screen_comparison.md`

## 精度对比

参考基线：`verify_logs/screen_baselines_it/float_screen6.jsonl`。

| 项目 | 结果 |
|---|---:|
| prompt 数量 | 6 |
| `OK` 数量 | 6/6 |
| 平均 ROUGE-L | 0.9479 |
| 乱码/复读/明显答非所问 | 未发现 |

逐条 ROUGE-L：`0.9670`、`0.9537`、`0.8251`、`1.0000`、`1.0000`、`0.9417`。其中中文 prompt 的 token match ratio 会受 tokenizer 分词方式影响，不能单独作为语义失败判据；本次逐条结果均为 `OK`。

## 可复现实验命令

```bash
source /workspace/jinghan.tan/miniforge3/etc/profile.d/conda.sh
conda activate mtk_gemma4_env
export PYTHONPATH=/workspace/xin.xu5/.local/lib/python3.12/site-packages:/workspace/jinghan.tan/miniforge3/envs/mtk_gemma4_env/lib/python3.12/site-packages:/workspace/jinghan.tan/miniforge3/envs/mtk_npu_np1002/lib/python3.12/site-packages
python scripts/verify/screen_quant_outputs.py \
  --out verify_logs/dynamic_2048_compare_20261014 \
  --title "dynamic_quant + 2048 calibration x86 vs FP32" \
  --cand quant_dynamic_2048_screen6=verify_logs/dynamic_2048_x86_20261014/quant_dynamic_2048_screen6.jsonl \
  --ref dynamic_2048_screen6=verify_logs/screen_baselines_it/float_screen6.jsonl
```

## 历史对照

此前仅使用 `quant_dynamic.json` 的实验曾出现 6/6 `GARBAGE`；该结果保留在 [旧记录](gemma4-dynamic-quant-x86-result-2026-10-13.md) 中。本次使用 2048 条语言均衡校准集后，x86 输出恢复为语义正常并通过对比。
