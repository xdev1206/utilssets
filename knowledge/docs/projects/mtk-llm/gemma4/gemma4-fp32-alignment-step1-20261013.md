# Gemma4 FP32 对齐验证：第一步（2026-10-13）

结论：随机英语 prompt 在 `mtk_inference_float_llm` FP32 下运行成功；同一 prompt 使用 HuggingFace greedy 推理得到完全相同的 32 个输出 token，第一步 FP32 对齐通过。

## 验证对象

- 模型：`gemma-4-E2B-it`
- MTK SDK：`4.0.1b2.post1.dev125+g10d6b0ede`
- Prompt：`Design a small project about community gardens; state its goal, three tasks, and one success metric.`
- 解码：greedy，`max_new_tokens=32`

## 结果

MTK 和 HuggingFace 输出均为：

```text
Here is a design for a small community garden project:

## Community Garden Project: "Green Sprouts Initiative"

**Goal:** To establish a small,
```

- MTK 返回码：`0`
- MTK prompt length：29 tokens
- 输出长度：32 tokens
- 输出文本一致：`True`
- 输出 token 一致：32/32
- 结论：`PASS`

## 注意事项

HF 对照必须使用原始 HuggingFace 模型目录；MTK farm 的 `config.json` 是部署配置，没有 HuggingFace 所需的 `model_type` 字段，不能直接作为 HF 模型目录。

详细命令和证据保存在部署项目的 `verify_logs/float_alignment_step1_20261013_random1/`。
