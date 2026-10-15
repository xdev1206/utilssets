# Gemma4 AudioEncoder 与 Text Model 集成实施方案

## 结论

AudioEncoder 不直接向 Gemma4 Transformer 输入 waveform，而是先把音频转换为一串与 Gemma4 `hidden_size` 相同的 embedding；运行时再用这些 embedding 替换 prompt 中的 `<audio>` 占位 token，和普通文本 token embedding 一起按顺序送入 Gemma4。

当前使用的 HF `gemma-4-E2B-it` checkpoint 已确认包含 AudioEncoder、VisionEncoder 以及到 Gemma4 text embedding 空间的投影权重；但 MTK Gemma4 部署工程目前只完成文本 LLM、token embedding 和 PLE 部署。运行时虽然预留了 `getAudioEmbedding()` 接口，但现有 `LlavaRuntime` 明确将 Audio 标记为未实现。因此本方案的第一目标是先完成 PC/HF 参考链路，再逐步落到 MTK NPU 和设备端。

## 当前状态（2026-10-14）

| 项目 | 状态 | 证据/说明 |
| --- | --- | --- |
| Gemma4 Text LLM | 已有部署链路 | `configs/gemma4/gemma4_e2b_device.yaml` |
| 多模态运行时抽象 | 已预留 | `MllmRuntime::getAudioEmbedding()` |
| 音频占位 token 分段 | 框架已预留 | `MllmRuntime::consumePrompt()` |
| HF AudioEncoder 权重 | 已确认 | `model.audio_tower.*`，751 个 tensor |
| HF VisionEncoder 权重 | 已确认 | `model.vision_tower.*`，658 个 tensor |
| HF modality projector | 已确认 | `model.embed_audio.embedding_projection.weight`、`model.embed_vision.embedding_projection.weight` |
| MTK AudioEncoder 推理实现 | 未实现 | 当前工程没有 AudioEncoder DLA/runner |
| MTK Audio-to-text projector | 未实现 | HF 有投影权重，MTK 图尚未拆分/转换 |
| Gemma4 设备端音频入口 | 未实现 | 当前 cmdline 工具没有 Gemma4 audio runner |
| 音频端到端验证 | 未开始 | 需先确定模型版本和音频格式 |

## HF checkpoint 核查结果

核查对象：`/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it`，当前部署目录中的 `work/gemma4_e2b_it/gemma-4-E2B-it/model.safetensors` 指向该文件。

| 组件 | 配置/权重证据 | 关键参数 |
| --- | --- | --- |
| AudioEncoder | `config.json: audio_config`；权重前缀 `model.audio_tower.*` | `model_type=gemma4_audio`，12 层，hidden 1024，`output_proj_dims=1536` |
| VisionEncoder | `config.json: vision_config`；权重前缀 `model.vision_tower.*` | `model_type=gemma4_vision`，16 层，hidden 768，默认 280 soft tokens |
| Audio projector | `model.embed_audio.embedding_projection.weight` | 输出到 1536 维 text embedding 空间 |
| Vision projector | `model.embed_vision.embedding_projection.weight` | 输出到 1536 维 text embedding 空间 |
| Audio processor | `processor_config.json` | 16 kHz，128-bin 特征，40 ms/token，最大序列 750 |
| Modality tokens | `config.json` / `tokenizer_config.json` | audio id 258881，image id 258880，video id 258884 |

因此应删除“HF checkpoint 未包含 AudioEncoder/VisionEncoder”的假设；当前真正的阻塞点是 MTK 转换、运行时资源加载和设备端多模态 prompt 接入。

## 目标数据流

```text
PCM / WAV / 音频文件
        |
        v
音频预处理（采样率、声道、归一化、分帧）
        |
        v
AudioEncoder（PC 参考模型或 MTK DLA）
        |
        v
Projector / connector / resampler
        |
        v
audio_embeds: [N_audio, 1536]
        |
文本 tokenizer: "请描述 <audio>"
        |
        v
占位 token 替换为 N_audio 个 audio_embeds
        |
        v
Gemma4 Text Transformer（prompt + decode）
        |
        v
文本 tokenizer 解码
```

核心约束：

1. Projector 输出维度必须等于 Gemma4 text model 的输入 embedding 维度；当前 E2B 配置为 1536。
2. AudioEncoder 输出的 token 数量可以固定或动态，但必须与占位 token 替换逻辑一致。
3. 量化、padding、position id、RoPE 和 KV cache 必须把音频 token 当作 prompt token 处理。
4. AudioEncoder 只参与 prompt 阶段；生成阶段复用 Gemma4 Text LLM 的 KV cache，不重复编码音频。

## 分阶段实施计划

### 阶段 0：模型与接口确认

- [x] 确认使用的是官方 Gemma4 E2B instruction-tuned multimodal checkpoint。
- [x] 确认 checkpoint 包含 AudioEncoder、VisionEncoder、两个 modality projector 和特殊 token。
- [x] 确认音频预处理基础参数：16 kHz、128-bin 特征、40 ms/token、序列上限 750。
- [ ] 进一步从 HF processor/model forward 实测音频 waveform 到 `audio_embeds[N,1536]` 的 shape 和投影顺序。
- [ ] 固化 MTK 接口：`audio waveform -> audio_embeds[N,1536]`。

验收：同一音频在 HF 侧能够生成稳定的音频 embedding，并能通过官方 multimodal model 生成合理文本。

### 阶段 1：HF/PC 参考链路

#### 第一项实现（review 后确定）

新增一个独立的 HF baseline 脚本，例如 `scripts/verify/hf_multimodal_baseline_gemma4.py`，只负责参考推理和中间结果导出，不修改 MTK 部署脚本。第一版先支持单音频、单图像和纯文本三种输入，音频和图像分别验证。

推荐流程：

1. `AutoProcessor.from_pretrained(HF_MODEL_DIR)` 加载官方 processor。
2. `AutoModelForMultimodalLM.from_pretrained(HF_MODEL_DIR, dtype="auto", device_map="auto")` 加载完整 checkpoint。
3. 使用模型自带 `apply_chat_template()` 构造 prompt，音频放在文本之后，图像按模型卡推荐位置放在文本之前。
4. 保存 processor 输出的 `input_ids`、attention mask、音频/图像输入张量及 shape。
5. 用 forward hook 或模型提供的输出字段捕获 `audio_tower`、`embed_audio.embedding_projection`、`vision_tower`、`embed_vision.embedding_projection` 和 text model 首层输入；若当前 Transformers 版本不暴露中间结果，增加最小的临时 hook，而不是复制模型实现。
6. 运行 greedy generation，保存输入、输出、模型版本、checkpoint 路径和 tensor 统计。

第一版不应做以下事情：

- 不把 AudioEncoder 单独导出为 TFLite；尚未确认 HF 内部输入/输出边界前导出会固化错误接口。
- 不手写 `<audio>` 或 `<image>` 的 token 拼接；必须使用官方 processor/chat template。
- 不把 750 个音频处理 token 直接等同于最终送入 LLM 的 audio soft tokens；需要从中间 tensor 实测 projector 和压缩过程。
- 不修改 `llm_cmdline_tool`；HF baseline 通过后再设计 MTK 图和 runtime 接口。

验收输出至少包括：`inputs.json`、`intermediates.json`、`hf_outputs.jsonl`、`summary.json`。其中 `summary.json` 必须记录 `audio_input_shape`、`audio_encoder_output_shape`、`audio_projected_shape`、`vision_projected_shape`、`text_hidden_size`、`n_audio_soft_tokens`、`n_image_soft_tokens` 和 `verdict`。

- [x] 新增 HF baseline 脚本，使用官方 processor/chat template 跑 text/audio/image 三种模式。
- [x] 保存 processor 输入、encoder/projector hook 摘要和 HF greedy 输出。
- [x] Gemma4 相关脚本命名统一包含 `gemma4`，便于检索和识别。
- [ ] 实现独立的音频预处理校验，并保存原始特征。
- [ ] 确认当前 Transformers 版本下 hook 捕获的 projector 输出与模型内部最终 LLM 输入一致。
- [ ] 验证 `<audio>` 占位 token 展开后的 token 数量、顺序和位置编码。
- [ ] 使用至少 3 条音频样本覆盖语音识别、问答和非语音声音描述。
- [ ] 建立 HF logits/生成结果基线。

验收：PC 侧直接拼接 embedding 的结果与官方 multimodal 推理结果语义等价；中间 tensor shape 和数值误差有记录。

### 阶段 2：AudioEncoder 导出与 MTK 转换

- [ ] 将 AudioEncoder 和 projector 拆分成可转换的计算图；优先保持 projector 与 encoder 分离，便于定位误差。
- [ ] 固定输入 shape 或定义动态 shape 集合。
- [ ] 导出 TFLite/中间格式并执行 MTK converter。
- [ ] 对比 HF、TFLite、MTK float 三个阶段的输出。
- [ ] 评估 AudioEncoder 的权重、激活、输入 embedding 精度和内存占用。

硬门禁：MTK float 输出必须先与 HF 参考对齐，确认通过后才允许 PTQ、fix-shape 或设备编译。

### 阶段 3：量化与设备图

- [ ] 为 AudioEncoder 和 projector 单独准备校准集；校准音频必须覆盖时长、音量、说话人和背景噪声分布。
- [ ] 分别评估 encoder、projector、Gemma4 text LLM 的量化误差。
- [ ] 确认 audio embedding 的设备输入类型、scale、layout 和对齐要求。
- [ ] 确认音频 token 数与 Gemma4 prompt batch/cache 上限的关系。
- [ ] 完成 AudioEncoder DLA、projector DLA 或融合图的固定 shape 编译。

### 阶段 4：运行时接入

- [ ] 新增 Gemma4 audio runtime，至少实现 `getAudioEmbedding()` 和 `getAudioEmbeddingSize()`。
- [ ] 注册 audio placeholder token，并将音频 buffer 映射到对应 media buffer。
- [ ] 明确 media buffer 顺序：文本中的第一个音频占位符对应第一个音频输入。
- [ ] 检查 prompt 分块、左 padding、right padding 和最后一步 logits。
- [ ] 音频只在 prompt 阶段编码一次，decode 阶段只运行 Text LLM。
- [ ] 增加音频输入格式、错误码和 shape mismatch 日志。

当前运行时已有的通用机制是：识别 audio placeholder，调用 `getAudioEmbedding()`，把返回 embedding 交给 embedding producer，再和文本 embedding 交错写入 LLM 输入 buffer。需要补齐的是 Gemma4 专用 encoder/projector 产生 embedding 的实现，以及设备资源加载。

### 阶段 5：端到端验证与发布

- [ ] HF、MTK float、MTK quant、设备端分别保存输出和中间结果。
- [ ] 记录 WER/CER（语音识别）、ROUGE-L/语义判定（问答或描述）、首 token 延迟、总延迟和内存。
- [ ] 覆盖无音频、单音频、多音频、超长音频、空音频和非法格式。
- [ ] 固化设备资源目录、yaml、运行命令和版本信息。
- [ ] 只有所有 float 对齐和端到端质量门禁通过后，才标记为可发布。

## 接口契约（待实现）

### AudioEncoder/projector 输出

```text
input:  float waveform/features, defined sample rate and channel layout
output: audio_embeds [1, N_audio, 1536]
dtype:  first use FP32/FP16 for alignment, then evaluate INT8/INT16
layout: token-major, contiguous
```

### Runtime 行为

```text
tokens:        text tokens containing AUDIO_PLACEHOLDER
mediaBuffers:  audio buffers in placeholder order
audio output:  N_audio embeddings per audio placeholder
LLM input:     text embeddings and audio embeddings in prompt order
decode:        reuse KV cache; do not rerun AudioEncoder
```

若模型使用 soft-token 机制，则需要另行确认占位 token 数是否等于 AudioEncoder 输出 token 数；不能直接沿用固定 image token 逻辑。

## 验证产物

每个阶段都应落盘，而不是只保留终端日志：

- `audio_inputs.jsonl`：音频路径、采样率、时长、解码参数。
- `audio_encoder_outputs/`：AudioEncoder 输出及 shape/dtype。
- `projector_outputs/`：projector 输出及统计信息。
- `hf_outputs.jsonl`、`mtk_float_outputs.jsonl`、`device_outputs.jsonl`。
- `comparison.md`：逐样本对比、首个异常位置和语义结论。
- `summary.json`：模型、工具链、shape、dtype、误差、延迟、verdict。

## 当前阻塞与决策点

1. **HF forward 路径待实测**：已确认组件和权重，但仍需用 `AutoProcessor`/`AutoModelForMultimodalLM` 导出中间 embedding，确认音频 token 数、projector 顺序和 mask。
2. **MTK runtime 实现缺失**：现有 `LlavaRuntime` 的 Audio 接口是 fatal stub，不能直接运行音频。
3. **设备资源格式未确定**：尚不能确定 AudioEncoder 是单独 DLA、与 projector 融合的 DLA，还是由 CPU/GPU 运行后把 embedding 喂给 NPU LLM。
4. **音频 token 预算待确认**：processor 配置上限为 750，但当前 Gemma4 MTK prompt batch 为 256，需要设计分块或重新编译 shape。

## 更新规则

- 每完成一个阶段，更新“当前状态”“分阶段计划”“验证产物”和“更新记录”。
- 新事实必须附文件、命令、日志或 tensor 对比证据；推测统一标记为“待确认”。
- 若模型、工具链或 runtime 发生变化，先更新本文件，再同步项目脚本和配置说明。
- 任何 float 对齐失败都将后续 PTQ/设备发布任务标记为阻塞。

## 更新记录

| 日期 | 更新内容 |
| --- | --- |
| 2026-10-14 | 初版：确认运行时预留 audio embedding 接口，但当前 Gemma4 部署未实现 AudioEncoder 接入；建立五阶段实施计划。 |
| 2026-10-14 | 核查 HF `gemma-4-E2B-it`：确认包含 `model.audio_tower`、`model.vision_tower` 以及 audio/vision projection 权重；更新阶段 0 和阻塞项。 |
| 2026-10-14 | Review 阶段 1 第一项实现：确定先新增 HF multimodal baseline 和中间 tensor 导出，暂不进行 MTK 导出或 runtime 修改。 |
| 2026-10-14 | 实现第一项：新增 `scripts/verify/hf_multimodal_baseline_gemma4.py`，完成 HF text/audio/image baseline 和中间摘要落盘。 |
| 2026-10-14 | Review 通过后修正图像 content part 使用模型卡约定的 `url` 字段，并移除未生效的 `--device` 参数。 |
| 2026-10-14 | HF smoke test：text/audio/image 均完成生成；公开音频样本 projector 输出 `[1,252,1536]`，图像样本 projector 输出 `[256,1536]`；补充 ModelOutput 的 `last_hidden_state` 摘要捕获。 |
| 2026-10-14 | 实施阶段 2 第一项：新增 `scripts/verify/gemma4_audio_encoder_export.py`，冻结 HF processor 输入、AudioEncoder 输出和 audio embedding 输出；暂不进行 MTK/TFLite 转换。 |
| 2026-10-14 | 执行 HF 导出：processor `input_features` 为 `[1,1007,128]`，`input_features_mask` 为 `[1,1007]`；`audio_tower` 与 `embed_audio` 均为 `[1,252,1536]`，但 cosine similarity 仅约 0.0077，确认两者不是同一 tensor，后续应以 `embed_audio` 作为最终 embedding 边界候选。 |

## 相关代码

- `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_runtime/mllm_runtime.h`
- `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_runtime/mllm_runtime.cpp`
- `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_runtime/llava_mllm_runtime.h`
- `configs/gemma4/gemma4_e2b_device.yaml`
