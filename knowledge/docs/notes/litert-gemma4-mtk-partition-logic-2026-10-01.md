# Gemma4 MTK NPU partition 判断逻辑调查（2026-10-01）

初步结论：LiteRT MediaTek plugin 有两条 partition 路径。`kSupportedOps` +
`VerifyCommonOp` 只表示 LiteRT legalization 层可尝试处理；当图包含 StableHLO
composite、op 数超过 1000，或 Neuron 不支持 UNKNOWN_OP 时，plugin 使用静态选择
逻辑，不调用 Neuron `getSupportedOperations`。其余图才把未通过 LiteRT 检查的 op
作为 `NEURON_UNKNOWN` 放入查询模型，再以 `NeuronCompilation_getSupportedOperations`
返回值决定 selected ops。

Gemma4 大图的静态路径额外排除：StableHLO composite、RMSNorm 名称相关 op、
Softmax、Reshape、Quantize、Dequantize，以及未通过 `IsOpSupported` 的 op。LiteRT
上层随后只把 selected ops 按数据依赖连接成 NPU islands；未选中的 op 留在 CPU。

本调查正在为两条路径增加逐 op 日志，记录 opcode、静态白名单结果、
`VerifyCommonOp` 结果、各排除条件、Neuron support flag 和最终 selected 结果。

已在 LiteRT plugin 中加入诊断日志，并完成 Bazel 编译。Bazel 单测默认不会自动把
NeuroPilot host SDK 加入动态链接路径；显式设置对应 SDK 的 `host/lib` 后，
`//litert/vendors/mediatek/compiler:compiler_plugin_test` 全部通过。此前的失败是
环境加载问题，不是 op 不支持。日志计数仍需在配置好同一 host SDK 的 Gemma4 转换
上复核。

## Gemma4 实测逐 op 结果（2026-10-01）

使用同一 Bazel 构建出的 `libLiteRtCompilerPlugin_MediaTek.so` 和
`apply_plugin_main_for_test`，对 `model_srq.litertlm.intermediate.tflite` 执行
`--cmd=partition --soc_model=mt6897`。4 个子图共 8337 个 op，全部进入静态
partition 路径，因此本次模型没有实际调用 Neuron `getSupportedOperations` 查询接口。

实测子图结果为 848 ops/300 selected、2037 ops/647 selected、1743 ops/652 selected、
3709 ops/1172 selected。主要拒绝原因是：`shlo.composite` 在边界处拒绝；
`tfl.reshape`、`tfl.dequantize`、`tfl.softmax` 被 shape/边界规则拒绝；
`tfl.cos`、`tfl.sin` 不在支持表；RMSNorm 区域中的 `add`、`mul`、`mean`、`rsqrt`
以及相关 `fully_connected`/`transpose` 按 RMSNorm 边界规则拒绝。完整逐 op 日志和
JSON 统计保存在项目工作目录的 `partition_diagnostic_20261001.log` 与
`partition_diagnostic_summary.json`。

## gemma4/mtk-npu-llm-deploy 的切图语义

该项目不是 LiteRT compiler plugin 的逐 op CPU/NPU partition 流程。它通过
`mtk_llm_sdk` 生成完整 TFLite，再用 `postprocess_quantized_model` 按 shared-KV
语义切成 prompt/opt 图和 tail 图，最后将每张图整体交给 `ncc-tflite` 编译为 MDLA
`.dla`。因此项目层面的 CPU/NPU 边界主要是图边界：tokenizer、prompt preformatter、
设备调度、KV/cache 组织和最终采样在 CPU；TFLite 图中保留的算子整体交给 MDLA，不能
仅凭该仓库源码声称某个单独 opcode 会自动 fallback CPU。

Gemma4 E2B 的实际图切法是：GEN 使用未 cut 的完整图（35 层，含 LM head）；PROM 使用
`*_opt_sharedkv.tflite`，从输入和 0~14 层 cache 输入出发，输出 `hidden_states_14`
及 0~14 层的 `curr_keys/curr_values`，即在最后一个有 cache 输出的层之后截断。工具还
生成 `*_tail_sharedkv.tflite`（从该边界到 `hidden_states_35`），但当前设备运行用
`--first-token-with-gen-model`，所以 tail 图不作为主执行图。每个图内部没有仓库维护的
CPU fallback 列表；MDLA 编译失败是整图失败，而不是自动把不支持 op 留给 CPU。

## LiteRT 完整复现 MTK LLM SDK Gemma4 的改造清单

不能只修改 LiteRT `kSupportedOps`。完整复现需要：Gemma4 model lowering、MTK PTQ
（权重、activation、KV、embedding/PLE 外部 bin 和精度配置）；PROM/GEN 固定 shape；
score path 的 INT16 rewrite；shared-KV cutter；full-graph MTK partition；MDLA DLA
与 shared-weight artifact；以及 LiteRT-LM 的 PROM/GEN/cache 调度。

LiteRT 可以把 GEN 全图交给一个 MTK partition，但前提是 `total_ops == selected_ops`、
最终 island 数为 1，且每个 op 都有 legalization 并能被 Neuron/MDLA finalize。当前
MTK plugin 的大图静态规则会主动拒绝 Softmax、Reshape、Quantize、Dequantize、RMSNorm
边界和 StableHLO composite，所以当前行为不是 MTK LLM SDK 的整图模式。
