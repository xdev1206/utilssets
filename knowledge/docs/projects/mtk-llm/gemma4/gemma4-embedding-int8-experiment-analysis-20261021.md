# Gemma4 embedding INT8 实验分析（2026-10-21）

## 结论

“embedding INT8”对应两次不同实验，不能混为一个结果：

1. 2026-10-15 的 x86 oracle 实验：`embedding` 和 `PLE` 均导出为 INT8 LUT；6 条 screen prompt 全部 `OK`，平均 ROUGE-L 为 `0.9213`。
2. 2026-10-19 的 NP8 手机实验：资产中同样包含 `embedding_int8.bin` 和 `ple_int8.bin`，但设备输出出现大量乱码；benchmark 只记录了性能和 `FAIL` 质量结论，没有可用的 ROUGE-L。

## x86 INT8 实验

配置：`dynamic_quant` decoder/tail，`default=int8`，`embeddings=int8`，`res_path=dynamic_quant`，`cache=int8`。`default=int8` 是 SDK 约束：若保留 `default=dynamic_quant` 再单独设置 `embeddings=int8`，会在 FP32 embedding 的 PTQ 收尾阶段失败。

- Token embedding：`embedding_int8.bin`，每个元素 1 byte；该实验使用完整词表，按 `262144 × 1536` 计算为 `402,653,184 B`。
- PLE：`ple_int8.bin`，每层 `262144 × 256`，35 层合计 `2,348,810,240 B`；每个元素 1 byte。
- 对比对象：FP32 screen6 输出；工具：`mtk_inference_quantized_llm` x86 oracle。
- 逐条 ROUGE-L：`0.8791, 0.9346, 0.8251, 1.0000, 1.0000, 0.8889`。
- 最终结果：`6/6 OK`，平均 ROUGE-L `0.9213`；相比 embedding dynamic_quant 基线 `0.9479`，下降 `0.0266`，未发现乱码或明显语义退化。

该结果证明的是 x86 侧 LUT 导出和量化图的数值质量，不等同于手机端验证。

## NP8 手机 INT8 实验

资产目录：`assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019`。这是后续英法词表裁剪后的设备资产，不是 2026-10-15 x86 实验的原始文件。

- `embedding_int8.bin`：`188,708,352 B`。
- `ple_int8.bin`：`1,100,798,720 B`。
- YAML：`embeddingFileType: INT8`，`modelInputType: INT16`；runtime 将有符号 INT8 LUT 符号扩展为图所需的 INT16。
- 初始化和推理返回码为 0，说明文件解析、模型初始化和执行链路跑通。
- 但 t0/t3/t4 输出含 `￿`、控制字符、混杂无效 token 等乱码，质量结论为 `FAIL`。
- 该记录没有生成与 FP32 对照的 ROUGE-L，因此不能填入 `0` 或复用 x86 的 `0.9213`。

该资产的 `188,708,352 B / 1,100,798,720 B` 对应 `122857` 行裁剪词表，不能用于推断完整词表 x86 实验的 LUT 大小。

性能记录：初始化约 `0.8196–0.8407 s`，Prefill `2286.4–2346.05 tok/s`，Decode `29.4894–30.7179 tok/s`。

## 判定

推荐将 2026-10-15 x86 实验作为“embedding/PLE INT8 的精度基线”：

- embedding：INT8，已通过 x86 精度门禁。
- PLE：INT8，已随同一 PTQ 流程导出并参与 x86 推理。
- ROUGE-L：`0.9213`（6 条平均，6/6 OK）。

2026-10-19 手机实验只能作为“INT8 文件和 runtime 路径已执行，但质量失败”的工程记录。后续应先定位设备侧乱码（尤其是 LUT 量化尺度/反量化、PLE 解释及 tokenizer/runtime 版本一致性），再重新计算设备 ROUGE-L。

## 2026-10-23 完整词表 INT8、无 Hessian PTQ

使用完整词表模型 `vocab_size=262144` 和配置
`work/gemma4_e2b_it/gemma4_quant_w4a16_embint8_20261016.json` 执行 PTQ；命令不包含
`-w hessian`，日志明确记录 `Weight optimization: None`。PTQ 成功完成 35 个 decoder layer
和 tail，返回码为 0。

产物目录：
`work/gemma4_e2b_it/quantized_models_w4a16_embint8_full_nohessian_20261023_retry/`。

- `embedding_int8.bin`: `402,653,184 B`
- `ple_int8.bin`: `2,348,810,240 B`
- TFLite layer 文件：36 个（layer 0–34 + tail 35）
- 有效 NumPy：`1.26.4`；必须设置 `PYTHONNOUSERSITE=1` 并清空 `PYTHONPATH`，避免用户级 NumPy 2.5.4 导致 `mlkits` ABI 错误。
- 本步骤只完成 PTQ/TFLite 和 INT8 LUT 导出；DLA 仍需后续 fix-shape、surgery、cut 和 MDLA 编译。

日志：
`work/gemma4_e2b_it/logs/ptq_w4a16_embint8_full_nohessian_20261023_retry.log`。

## 2026-10-23 完整词表 INT8 无 Hessian fix-shape

对上述 PTQ 输出执行：
`mtk_fix_llm_shape <ptq> 256t 1t 4096c -o <fixed> --opt_swa --force_overwrite`。
fix-shape 返回码为 0，耗时约 6 分 35 秒。

固定形状产物：
`work/gemma4_e2b_it/quantized_models_fixed_w4a16_embint8_full_nohessian_20261023_retry/`。

- `llm/llm_1t4096c/*.tflite`：1 个
- `llm/llm_256t4096c/*.tflite`：1 个
- `embedding_int8.bin`：`402,653,184 B`
- `ple_int8.bin`：`2,348,810,240 B`
- `config.json` 和两个 shape info 均确认 `vocab_size=262144`
- tokenizer 文件已复制到 `tokenizer_files/`

日志：
`work/gemma4_e2b_it/logs/fix_shape_w4a16_embint8_full_nohessian_20261023_retry.log`。

## 2026-10-23 完整词表 INT8 无 Hessian score-path surgery

旧版 `scripts/recipe_exp/fix_scorepath.py` 不兼容当前 `mtk_converter 10.6.0`：它只查找
旧 tensor 名 `softmax_dequantized`，并在当前图的 FLOAT32 softmax tensor 上触发断言。
该失败没有写回 TFLite。

随后改用 `scripts/deploy/gemma4_v2/fix_scorepath.py`，对 `256t4096c` 和 `1t4096c`
两个固定形状图原地执行 surgery，并加 `--np-compat 8`。每张图均完成：

- 177 个 tensor 从 FLOAT32 改为 INT16（2 个 mask + 35 层 × 5 个 score-path tensor）；
- 自动读取 `S_SM=3.0518509447574615e-05`；
- 1 个 `FULLY_CONNECTED` opcode 从 v13 修正为 NP8 支持的 v11；
- `missing=0`，返回码为 0。

复核结果：两个图均为 `177/177 INT16`、`F32=0`，并写入 `.fixsp.done`。

日志：
`work/gemma4_e2b_it/logs/surgery_w4a16_embint8_full_nohessian_20261023_retry_v2.log`。

## 2026-10-23 完整词表 INT8 无 Hessian PROM cut

对 surgery 后的两个固定形状图执行 release 脚本
`third_party/mtk_gemma4_release_20260911/script/cut_tflite_nanov4.sh`，返回码为 0。

生成 4 个文件：

- `llm_1t4096c/cut/*_opt_sharedkv.tflite`
- `llm_1t4096c/cut/*_tail_sharedkv.tflite`
- `llm_256t4096c/cut/*_opt_sharedkv.tflite`
- `llm_256t4096c/cut/*_tail_sharedkv.tflite`

I/O 核对：prompt 图输出 `hidden_states_14` 和 KV；tail 图输入 `hidden_states_14` 及末端 KV，输出 `hidden_states_35`。日志：
`work/gemma4_e2b_it/logs/cut_w4a16_embint8_full_nohessian_20261023_retry.log`。

## 2026-10-23 完整词表 INT8 无 Hessian NP8 MDLA 编译

使用 NP8 SDK 8.0.11、目标 `MT6899` 执行 `scripts/deploy/gemma4_v2/5_build_mdla.sh all`，返回码为 `0`。PROM/GEN 和 `extract-shared` 均成功；PROM 编译 DRAM 约 `330M`，GEN 编译 DRAM 约 `1.1G`，共享静态权重为 `295,798,784 B`。

产物目录：`work/gemma4_e2b_it/quantized_models_fixed_w4a16_embint8_full_nohessian_20261023_retry/mdla_build_np8/`。

- `llm_256t4096c/cut/*_opt_sharedkv.dla`：`300,089,213 B`
- `llm_256t4096c/cut/*_opt_sharedkv_shared.dla`：`3,014,687 B`
- `llm_1t4096c/*_1t4096c_0.dla`：`1,177,431,661 B`
- `llm_1t4096c/*_1t4096c_0_shared.dla`：`880,025,799 B`
- `gemma4_e2b_it_full_embint8_nohessian_np8_sha.bin`：`295,798,784 B`

GEN 使用未 cut 的完整图，PROM 使用 cut 图，符合 `--first-token-with-gen-model` 的运行组合。日志：`work/gemma4_e2b_it/logs/mdla_np8_w4a16_embint8_full_nohessian_20261023_retry.log`。

至此该实验已完成 PTQ、fix-shape、surgery、cut 和 NP8 MDLA 编译；assets 打包、设备 push 与端侧 benchmark 仍待执行。
