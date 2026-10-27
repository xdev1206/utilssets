# Gemma4 W4A16 + embedding INT8 + tail W8A16 + residual INT16 PTQ（中断，2026-10-16）

## 配置

配置文件：`work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_tailw8a16_resint16_2048.json`

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
    "res_path": "int16",
    "embeddings": "int8",
    "logits": "float",
    "cache": "int8"
}
```

## 执行状态

PTQ 使用 2048 条校准集，输出目录为：
`work/gemma4_e2b_it/quantized_models_w4a16_embint8_tailw8a16_resint16_2048`

日志：
`work/gemma4_e2b_it/logs/ptq_w4a16_embint8_tailw8a16_resint16_20261016.log`

SDK 日志确认 `Residual path precision: int16` 已生效。用户要求停止后终止 PTQ；layer 0、1、2 已成功生成 TFLite，layer 3 转换过程中中断。已生成 `embedding_int8.bin` 和 `ple_int8.bin`。

本次未完成完整 PTQ，未执行 fix-shape、x86 量化精度对比、MDLA 编译或设备验证，不能据此判断量化精度。
