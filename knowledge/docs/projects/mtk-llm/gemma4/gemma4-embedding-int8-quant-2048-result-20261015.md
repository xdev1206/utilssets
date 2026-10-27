# Gemma4 embedding int8 PTQ 结果（2026-10-15）

## 结论

Gemma-4-E2B-it 使用 embedding `int8` 后，完整 PTQ、fix-shape 和 x86 量化推理均成功。6 条 screen prompt 与 FP32 `-it` 基线对比为 `OK` 6/6，平均 ROUGE-L 为 `0.9213`。相比 embedding `dynamic_quant` 基线的 `0.9479`，下降 `0.0266`，仍未出现乱码、复读或明显语义退化。

该结论仅覆盖 x86 oracle；尚未完成 NP8/MDLA 编译和手机端验证。

## 配置和 SDK 约束

目标配置文件：`work/gemma4_e2b_it/gemma4_quant_dynamic_embint8_2048_defaultint8.json`。

```json
{
    "llm": {
        "0-34": "dynamic_quant"
    },
    "tail": "dynamic_quant",
    "default": "int8",
    "softmax": "float",
    "res_path": "dynamic_quant",
    "embeddings": "int8",
    "logits": "float",
    "cache": "int8"
}
```

注意：仅把 `embeddings` 改成 `int8`、同时保留 `default=dynamic_quant` 时，PTQ 在 layer 0 TFLite 生成后失败：

`Unable to quantize float embedding inputs/outputs outside of PTQ flow.`

原因是该 SDK 会把 `default=dynamic_quant` 解析成 FP 激活，embedding 输入仍是 FP32，最终收尾阶段不能把 FP32 embedding 再转换成 int8。将 `default` 设为 `int8` 后，SDK 才在 PTQ 流程内生成真正的 int8 embedding 输入和 `embedding_int8.bin`。因此本次实验不只是 embedding 字段变化，`default` 也必须改为 `int8`，这是 SDK 兼容性前提。

## 执行和产物

- 校准集：`work/gemma4_e2b_it/calibration_datasets/gemma-4-E2B-it_2048`
- PTQ 输出：`work/gemma4_e2b_it/quantized_models_dynamic_embint8_2048`
- fix-shape 输出：`work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_embint8_2048_compat`
- embedding LUT：`embedding_int8.bin`
- PLE LUT：`ple_int8.bin`
- PTQ 日志：`work/gemma4_e2b_it/logs/ptq_dynamic_embint8_2048_full_20261015.log`
- fix-shape 日志：`work/gemma4_e2b_it/logs/fix_shape_dynamic_embint8_2048_compat_20261015.log`
- x86 输出：`verify_logs/dynamic_embint8_2048_x86_20261015/quant_dynamic_embint8_2048_screen6.jsonl`
- 对比汇总：`verify_logs/dynamic_embint8_2048_compare_20261015/screen_summary.json`
- 逐条对比：`verify_logs/dynamic_embint8_2048_compare_20261015/screen_comparison.md`

## SDK fix-shape 兼容补丁

embedding int8 配置在 fix-shape 的 layer 15 首次失败，错误为：

`The keys of the input_name_mappings argument should be one of the input tensor names in the imported subgraph.`

失败前日志显示 SDK 对 `curr_shared_key/value_*` 插入了 quantize op，但没有同步更新 `input_name_mappings`。项目脚本 `scripts/verify/run_fix_shape_mapping_compat.py` 在 `ModelBuilder.import_subgraph` 调用前，将唯一匹配的 `<name>_float`/`<name>_quantized` 输入名映射回正确目标，未改变计算图和量化参数。使用该包装器后 fix-shape 返回码为 0。

## 精度对比

参考：`verify_logs/screen_baselines_it/float_screen6.jsonl`。

| 配置 | OK | 平均 ROUGE-L |
|---|---:|---:|
| dynamic_quant + embedding dynamic_quant | 6/6 | 0.9479 |
| dynamic_quant + embedding int8（本次） | 6/6 | 0.9213 |

本次逐条 ROUGE-L：`0.8791`、`0.9346`、`0.8251`、`1.0000`、`1.0000`、`0.8889`。相比动态 embedding，qid0 从 `0.9670` 降至 `0.8791`，qid5 从 `0.9417` 降至 `0.8889`；qid1 轻微下降，qid2/3/4 基本不变。

## 历史和限制

- embedding int8 的 PTQ/fix-shape/x86 oracle 已通过。
- 该版本尚未执行 NP8/MDLA 编译和设备端测试。
- 由于 `default` 必须设为 int8，不能把本结果严格解释成仅 embedding 一项变化；后续若要隔离 embedding 单项损失，需要 SDK 支持“FP default + int8 embedding”的 PTQ 入口，或在图级别单独插入并验证 embedding quantize/dequantize。
