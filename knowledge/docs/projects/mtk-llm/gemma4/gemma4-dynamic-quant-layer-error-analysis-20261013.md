# Gemma4 动态量化误差逐层分析（2026-10-13）

## 结论

`dynamic_quant` 并没有让 Gecko4/Gemma4 图中的所有激活保持 FP32。SDK 将线性层实现为 INT8 权重 + FP32 动态激活，但 embedding、PLE 和层间 hidden-state 接口仍包含 INT16 量化。当前动态量化 x86 推理 6/6 条输出为乱码，平均 ROUGE-L 为 0.2432，首个 token 即不匹配，因此不能进入 MDLA 或设备验证。

## 证据

- 配置：`quant_dynamic.json`；LLM/tail/residual/embedding 为 `dynamic_quant`，softmax/logits 为 FP，cache 为 INT8。
- PTQ、fix-shape 和 x86 推理返回码均为 0，但 screen6 对比 6/6 `GARBAGE`，平均 ROUGE-L `0.2432`，token match ratio 全部为 0。
- 典型输出包括多语言乱码、`<|channel>thought` 等异常 token、无意义重复和错误翻译/问答。
- PTQ 日志：`logs/ptq_dynamic_20261013.log`；配置为 `dynamic_quant`，校准数据为 `fake`，并记录 `Skipping calibration as no static quantizers are present.`
- fixed-shape 图：`work/gemma4_e2b_it/quantized_models_dynamic_fixed/llm/llm_1t4096c/quantized_models_dynamic_fixed_1t4096c_0.tflite`。
- 该图包含 311 个 `FULLY_CONNECTED`、139 个 `QUANTIZE`、105 个 `DEQUANTIZE`；`input_embeds_0` 为 INT16，`hidden_states_0/1/34` 为 INT16，`hidden_states_35` 才是 FP32。
- 35 个 decoder 层 hidden-state 输出尺度范围为 `0.000296589`（layer 11）到 `0.001661297`（layer 14），对应 INT16 可表示绝对范围约 `±9.72` 到 `±54.44`。
- x86 结果：`verify_logs/dynamic_quant_x86_20261013/screen_summary.json`，6 条均为 `GARBAGE`，首 token mismatch index 均为 0。
- 外部项目的逐条输出和补充日志：`/workspace/xin.xu5/projs/gemma_projs/gemma4/mtk-npu-llm-deploy/verify_logs/dynamic_quant_x86_20261013/README.md`。

## 根因判断

当前最可能的根因是“动态权重量化”和 Gecko4 必需的层间 INT16 接口量化叠加，而不是 RoPE 或 chat template。动态配置还将 `embeddings` 设为 `dynamic_quant`；SDK 对该项特殊映射为 `sym8W_dynamic_quant`，所以 embedding/PLE 路径也进入量化图。由于动态量化路径没有静态激活校准，层间 hidden-state/PLE 的固定 INT16 scale 没有用真实 500 条校准文本验证，可能导致首层或早期层的截断/尺度误差，并在后续层放大。

## 消融证据

- 仅将 `embeddings` 改为 `FP`，decoder 仍全动态：6/6 `GARBAGE`，平均 ROUGE-L `0.2315`，首 token 全部 mismatch；因此 embedding 不是唯一根因。
- 仅将 layer 0 设为 `dynamic_quant`、其余 decoder 设为 FP，embedding/residual/tail 保持动态：6/6 `GARBAGE`，平均 ROUGE-L `0.1718`，首 token 全部 mismatch。shape fixer 对 layer 0 输出到 layer 1 FP 输入插入 `DEQUANTIZE`。
- 仅 tail 动态而 decoder 全 FP 的组合在 layer 35 触发 `IndexError: list index out of range`，属于 SDK 混合精度转换失败，不能作为 tail 数值结论。

因此误差已收敛到 layer 0 动态 FC 或其 INT16 hidden-state→FP 输入边界，尚未证明是后续层累积。

layer0 TFLite 与 FP 控制图的直接差异：FP 图的 `input.1` 与 layer0 hidden 输出均为 FP32；dynamic 图的 `input.1` 为 INT16（scale `0.0001583116`），`per_layer_model_proj` 权重为 INT8，layer0 hidden 输出为 INT16（scale `0.0004145791`），再由 shape fixer 插入 `DEQUANTIZE` 接入 layer1 FP。该首层量化边界是目前最直接、最可复现的误差来源。

## 下一步验证顺序

1. 保持 decoder 线性层 `dynamic_quant`，将 `embeddings`、`res_path`、`tail` 改为 `float`，重新 PTQ、fix-shape，并运行同一组 6 条 prompt。
2. 若首 token 恢复，分别只恢复 `embeddings`、`res_path`、`tail` 中的一项量化，定位首个产生误差的路径。
3. 若仍失败，改为只量化早期/后期 decoder 层的权重，按层段二分（0-4、5-9……）定位动态权重量化不兼容的层。
4. 每个候选配置都必须先完成 x86 FP32 对齐；未达到语义 PASS 前不得编译 MDLA 或上设备。

