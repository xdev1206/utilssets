# Gemma4 W4A16 + embedding INT8 + tail W8A16 PTQ 结果（2026-10-15）

## 配置

配置文件：`work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_tailw8a16_2048.json`

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
    "tail": "sym8W_sym16A",
    "default": "int8",
    "softmax": "float",
    "res_path": "sym4W_sym16A",
    "embeddings": "int8",
    "logits": "float",
    "cache": "int8"
}
```

## PTQ

执行命令：

```bash
source /workspace/jinghan.tan/miniforge3/etc/profile.d/conda.sh
conda activate mtk_gemma4_env
export PYTHONPATH=/workspace/xin.xu5/.local/lib/python3.12/site-packages:/workspace/jinghan.tan/miniforge3/envs/mtk_gemma4_env/lib/python3.12/site-packages:/workspace/jinghan.tan/miniforge3/envs/mtk_npu_np1002/lib/python3.12/site-packages
mtk_ptq_llm ./gemma-4-E2B-it/config.json \
  -d calibration_datasets/gemma-4-E2B-it_2048 \
  --opt ./gemma4_quant_w4a16_embint8_tailw8a16_2048.json \
  --force-overwrite -f tflite \
  -o ./quantized_models_w4a16_embint8_tailw8a16_2048 \
  2>&1 | tee logs/ptq_w4a16_embint8_tailw8a16_20261015_retry.log
```

PTQ 成功生成第 0–34 层和 tail layer 35，共 36 个 TFLite 图；成功导出 `embedding_int8.bin` 和 `ple_int8.bin`。耗时 2:09:43，RAM 峰值 48.18 GB，VRAM 峰值 36.59 GB。

## fix-shape

由于 embedding INT8 会触发 SDK 的 shared-KV 输入映射兼容问题，使用项目兼容 wrapper：

```bash
python scripts/verify/run_fix_shape_mapping_compat.py \
  ./quantized_models_w4a16_embint8_tailw8a16_2048 256t 1t 4096c \
  --opt-swa --np-compat 10 --force-overwrite \
  -o ./quantized_models/quantized_models_w4a16_embint8_tailw8a16_2048 \
  2>&1 | tee logs/fix_shape_w4a16_embint8_tailw8a16_20261015.log
```

fix-shape 成功生成 `256t4096c` 和 `1t4096c`，耗时 8:19；没有再次出现 stale `input_name_mappings` 错误。

## x86 对比

第一次推理因 PYTHONPATH 未包含 `mtk_gemma4_env` SDK，错误为 `Unsupported model_type: gecko4`；修正 PYTHONPATH 后重跑成功。

量化推理结果：

- 输出：`verify_logs/w4a16_embint8_tailw8a16_x86_20261015/quant_w4a16_embint8_tailw8a16_screen6.jsonl`
- 对比：`verify_logs/w4a16_embint8_tailw8a16_compare_20261015/`
- prompts：6 条
- `GARBAGE`：6/6
- 平均 ROUGE-L：`0.0897`
- 首 token mismatch：6/6

逐条 ROUGE-L：`0.0000, 0.1176, 0.0508, 0.2381, 0.0530, 0.0787`。输出主要为 `<turn|>`、单字符或乱码，属于严重语义退化。

## 结论

`default=int8 + embeddings=int8 + tail=sym8W_sym16A` 不能修复 W4A16 的精度问题，反而仍然严重退化。该配置未通过 x86 精度门禁，不得继续 MDLA 编译或上设备。后续应优先恢复更高精度的 decoder/residual 配置，再单独评估 tail 和 embedding 的影响。
