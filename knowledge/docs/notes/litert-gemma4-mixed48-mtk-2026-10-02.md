# LiteRT Gemma4 mixed48 MTK 验证（2026-10-02）

`gemma4_mixed48` 是按 `.litertlm` section 组织的 recipe，不能作为单一主图
recipe 直接传给 Gemma4 Stage 1。实际执行必须从 Float bundle 开始，分别量化
`tf_lite_embedder`、`tf_lite_per_layer_embedder` 和 `tf_lite_prefill_decode`，再
重新打包并执行 MediaTek Stage 4。

在 `mt6897`、Neuron API 8.2.30 上，Float 导出、校准和三段量化均完成；Stage 4
在 `tf_lite_prefill_decode` 首个 FullyConnected 编译时失败：
`Invalid FullyConnectedLayer: Bias should be floating point type`。因此当前
LiteRT/MTK compiler 组合没有可部署的 mixed48 NPU bundle，不能继续端侧 benchmark。

复现输出目录：
`/workspace/xin.xu5/projs/litert/work/gemma4_e2b_mixed48_20261002`
