# Gemma4 动态量化 x86 对齐结果（2026-10-13）

动态量化配置可被 SDK 接受并成功生成 TFLite，但 x86 生成质量不通过，不能进入 NP8/MDLA 编译。

- 配置：`quant_dynamic.json`，LLM/tail/residual/embedding 为 `dynamic_quant`，softmax/logits 为 FP，cache 为 INT8。
- `dynamic_quant` 解析为 INT8 权重 + FP32 动态激活；不需要静态 calibration。
- PTQ 返回码：0；fix-shape 返回码：0；x86 推理返回码：0。
- 与 FP32 `-it` screen6 基线比较：6/6 `GARBAGE`，平均 ROUGE-L `0.2432`，token match ratio 全部为 0。
- 典型现象：多语言乱码、`<|channel>thought` 等异常 token、无意义重复、翻译和问答均失败。

详细命令和逐条结果：
`/workspace/xin.xu5/projs/gemma_projs/gemma4/mtk-npu-llm-deploy/verify_logs/dynamic_quant_x86_20261013/README.md`。
