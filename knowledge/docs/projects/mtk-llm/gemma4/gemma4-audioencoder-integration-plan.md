# Gemma4 AudioEncoder 与 Text Model 集成实施方案

## 结论

AudioEncoder 不直接向 Gemma4 Transformer 输入 waveform，而是先把音频转换为一串与 Gemma4 `hidden_size` 相同的 embedding；运行时再用这些 embedding 替换 prompt 中的 `<audio>` 占位 token，和普通文本 token embedding 一起按顺序送入 Gemma4。

当前使用的 HF `gemma-4-E2B-it` checkpoint 已确认包含 AudioEncoder、VisionEncoder 以及到 Gemma4 text embedding 空间的投影权重；但 MTK Gemma4 部署工程目前只完成文本 LLM、token embedding 和 PLE 部署。运行时虽然预留了 `getAudioEmbedding()` 接口，但现有 `LlavaRuntime` 明确将 Audio 标记为未实现。因此本方案的第一目标是先完成 PC/HF 参考链路，再逐步落到 MTK NPU 和设备端。

## 当前状态（截至 2026-10-16）

| 项目 | 状态 | 证据/说明 |
| --- | --- | --- |
| Gemma4 Text LLM | 已有部署链路 | `configs/gemma4/gemma4_e2b_device.yaml` |
| 多模态运行时抽象 | 已预留 | `MllmRuntime::getAudioEmbedding()` |
| 音频占位 token 分段 | 框架已预留 | `MllmRuntime::consumePrompt()` |
| HF AudioEncoder 权重 | 已确认 | `model.audio_tower.*`，751 个 tensor |
| HF VisionEncoder 权重 | 已确认 | `model.vision_tower.*`，658 个 tensor |
| HF modality projector | 已确认 | `model.embed_audio.embedding_projection.weight`、`model.embed_vision.embedding_projection.weight` |
| MTK AudioEncoder/projector float 图 | 已转换并通过 HF 边界对齐 | 单音频 TFLite 输出 `[252,1536]`，cosine `0.999709`；本次使用 `mtk_converter 9.8.0` |
| MTK AudioEncoder 推理实现 | 未实现 | 当前工程没有 AudioEncoder DLA/runner |
| MTK Audio-to-text projector 设备接入 | 未实现 | float TFLite 已包含 projector，尚未作为设备资源加载 |
| Gemma4 设备端音频入口 | 未实现 | 当前 cmdline 工具没有 Gemma4 audio runner |
| 音频端到端验证 | 未开始 | encoder/projector 边界已过；Text LLM 与设备 runtime 尚未接入 |

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
- [x] 从 HF processor/model forward 实测音频到 `audio_embeds[N,1536]` 的 shape 和投影顺序。
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
- [x] 确认 HF projector 输出与模型内部最终 LLM 音频输入一致。
- [x] 验证当前样本 `<audio>` 占位 token 展开后的数量和顺序（252 个 token）。
- [ ] 使用至少 3 条音频样本覆盖语音识别、问答和非语音声音描述。
- [ ] 建立 HF logits/生成结果基线。

验收：PC 侧直接拼接 embedding 的结果与官方 multimodal 推理结果语义等价；中间 tensor shape 和数值误差有记录。

### 阶段 2：AudioEncoder 导出与 MTK 转换

- [ ] 将 AudioEncoder 和 projector 拆分成可转换的计算图；优先保持 projector 与 encoder 分离，便于定位误差。
- [ ] 固定输入 shape 或定义动态 shape 集合。
- [x] 导出 TFLite 并执行 MTK converter。
- [x] 对比 TFLite 输出与 HF Text Model 实际音频输入 embedding。
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

1. **MTK runtime 实现缺失**：现有 `LlavaRuntime` 的 Audio 接口是 fatal stub，不能直接运行音频。
2. **设备资源格式未确定**：尚不能确定 AudioEncoder 是单独 DLA、与 projector 融合的 DLA，还是由 CPU/GPU 运行后把 embedding 喂给 NPU LLM。
3. **音频 token 预算待确认**：processor 配置上限为 750，但当前 Gemma4 MTK prompt batch 为 256，需要设计分块或重新编译 shape。

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
| 2026-10-15 | 读取 Transformers Gemma4 实现确认内部链路：AudioEncoder 为下采样卷积 + 12 层 hidden 1024 音频 Transformer + `output_proj(1024→1536)`；`embed_audio` 继续执行 RMSNorm + `embedding_projection(1536→1536)`，其输出才被 masked-scatter 到 Text LLM 输入。 |
| 2026-10-15 | 独立两阶段 HF 对齐通过：`audio_tower → embed_audio` 与官方 `get_audio_features()` 的有效输出 `max_abs_error=0`、cosine≈1，确认可以按两个边界进入后续 MTK 导出。 |
| 2026-10-15 | MTK wrapper 首次导出受环境阻塞：`torch.export` 可捕获图但当前 PyTorch 2.14.1 的 ExportedProgram 序列化失败；MTK converter V2 要求并验证 `2.1 <= torch < 2.9`，需切换专用兼容环境后再导出。 |
| 2026-10-16 | 修复 trace 参数别名错误：trace 时 `per_dim_scale` 已替换为 `softplus(per_dim_scale)`，但 trace 后恢复原参数会改变 TorchScript 持有的参数，导致 attention softmax 偏移。保留折叠值后，第 0 层 softmax trace 与 HF eager 最大误差为 0。 |
| 2026-10-16 | 完整音频 TFLite 经 `mtk_converter 9.8.0` 转换；TFLite/HF 实际 Text Model 音频输入边界 cosine=`0.999709`、global relative error=`0.018019`，verdict=`PASS`。产物：`logs/gemma4_audio_scale_fix/`。当前环境 PyTorch 2.14.1 超出该 converter 已声明支持范围，仍需在 PTQ 所用 converter 版本复核。 |

## 已确认的 HF 音频计算边界

```text
input_features [B, T, 128]
  → subsample_conv_projection
      Conv2d(1→128) → LayerNorm → ReLU
      Conv2d(128→32) → LayerNorm → ReLU
      input_proj_linear(1024→1024)
  → relative positional encoding
  → 12 × Gemma4AudioLayer(hidden=1024)
  → audio_tower.output_proj(1024→1536)
  → embed_audio.embedding_pre_projection_norm(RMSNorm 1536)
  → embed_audio.embedding_projection(1536→1536)
  → 去除 padding audio soft tokens
  → 替换 input_ids 中的 audio placeholder
  → Gemma4 Text LLM
```

HF `Gemma4Model.get_audio_features()` 明确执行：

1. `audio_tower(input_features, input_features_mask)`；
2. `embed_audio(audio_outputs.last_hidden_state)`；
3. 用 encoder 返回的有效位置 mask 去除 padding；
4. 将最终 audio features 与 `<|audio|>` token slots 做数量检查后 masked-scatter 到文本 embedding。

因此 MTK 拆图的首选边界是：

- 图 A：`input_features + input_features_mask -> audio_tower.output_proj`；
- 图 B：`audio_tower_output -> embed_audio -> final audio embeddings`；
- 运行时根据有效 audio token 数，把图 B 输出插入 Text LLM prompt。

暂不把 `input_features_mask` 简化为普通 attention mask；它同时决定 encoder 有效输出位置和最终 padding token 去除行为。

独立对齐脚本：`scripts/verify/gemma4_audio_stage_alignment.py`。结果：`logs/gemma4_audio_stage_alignment/summary.json` 和 `stage_alignment.pt`。

## MTK 导出环境门禁

当前环境实际为 `torch 2.14.1+cu130`。虽然独立 PyTorch V2 导出曾受版本/序列化问题影响，
但同一环境中的 `mtk_ptq_llm` 已成功转换 LLM；因此 AudioEncoder 不再以 PyTorch 版本
范围作为门禁，直接复用该成功环境中的 `mtk_converter` 流程进行实测。

本次尝试中：`torch.jit.trace` 因 Transformers blocked-mask/vmap 失败；`torch.export.export` 图捕获成功，但 `torch.export.save` 因当前版本的自定义 `TreeSpec` 序列化失败。当前没有生成可交给 `mtk_pytorch_v2_converter` 的 `.pt2` 文件。

## 相关代码

- `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_runtime/mllm_runtime.h`
- `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_runtime/mllm_runtime.cpp`
- `third_party/llm_cmdline_tool-v1.11.1/jni/prebuilt/src/llm_runtime/llava_mllm_runtime.h`
- `configs/gemma4/gemma4_e2b_device.yaml`

此前 TFLite→HF Text boundary cosine=`0.7518207`、max_abs_error=`29.1614`。根因已定位：
`_install_converter_op_rewrites()` 在 trace 前把 `per_dim_scale` 原地改成 softplus 值，
并把 `functional.softplus` 替换为恒等函数；trace 完成后恢复原始参数时，TorchScript
仍引用同一参数对象，导致运行图使用未折叠 scale。attention logits 的 cosine 虽接近 1，
scale 偏差经 softmax 放大后使概率 cosine 降到约 `0.594`。

修复是让 trace 与 TFLite 转换期间保持 softplus 折叠后的参数。修复后的第 0 层 softmax
trace/HF eager max_abs_error=`0`、TFLite/trace cosine=`1.0`。完整 TFLite 的 converter
回读 cosine=`0.99999994`、max_abs_error=`0.0001302`；对比实际送入 HF Text Model 的
252 个 audio token embedding，cosine=`0.999709`、mean_abs_error=`0.03793`、
global_relative_error=`0.018019`，verdict=`PASS`。结果保存在
`logs/gemma4_audio_scale_fix/`，旧 FAIL 产物保留为历史记录，不再代表当前状态。

下一步是冻结 HF AudioEncoder 到 Text Model 的实际边界：新增
`scripts/verify/gemma4_audio_text_boundary.py`，保存 AudioEncoder/projector 完成后
传给 `model.language_model` 的 `inputs_embeds`、attention mask、position ids 和
per-layer inputs。该边界用于后续 MTK Text Model 对接；在 MTK runtime 明确支持
Gemma4 Audio 前，不进入设备端集成。
HF Text Model 边界已冻结在 `logs/gemma4_audio_text_boundary/`。新的
`scripts/verify/gemma4_audio_tflite_boundary_alignment.py` 检查 MTK TFLite 与其中真实
audio token positions 的 embedding；与 converter 输入的 `input_features` 和 mask 逐元素
相同后再比较，避免拿 trace reference 代替 HF 基线。float 边界门禁已通过；后续仍须在
PTQ 所用 `mtk_converter 10.6.0` 环境复核，再开始 PTQ/fix-shape/MDLA 和 runtime 工作。

## MTK converter 复用决策

AudioEncoder 的正式转换必须复用成功 PTQ 所在环境中的 `mtk_converter`，并通过与
`mtk_ptq_llm` 相同的 LLM SDK converter 流程处理；不采用当前环境的独立
`torch.jit.trace`/`torch.export` 结果作为部署产物，也不把通用的
`mtk_pytorch_v2_converter` 当作 `mtk_ptq_llm` 的等价替代入口。

成功 PTQ 环境的 SDK 已发现部分 Gemma4 支持：`gemma4_quantized` 的 LLM/embedder、
Gemma4 专用量化参数映射，以及 PTQ 中对 `audio_tower` 的处理逻辑均存在；但没有
独立的 `gemma4_audio` encoder 类。因此下一步应定位该 SDK 的 Gemma4 全模型配置
格式，优先复用现有全模型 PTQ 入口，不把 Gemma4 AudioEncoder 伪装成
`qwen2_audio` 或 `whisper`。

已确认：`mtk_ptq_llm` 和 `mtk_fix_llm_shape` 使用 `mtk_converter` 后端；后者处理
PTQ 产物的 shape 固定，不负责重新导入 HF AudioEncoder。

本项目已新增独立入口 `scripts/convert/gemma4_audio_mtk_converter.py`：加载 HF
已验证的 `audio_tower + embed_audio`，封装为纯 Tensor 图后调用
`mtk_converter.PyTorchConverter` 输出 TFLite/MLIR。该入口要求配套 MTK 环境的
与已成功执行 `mtk_ptq_llm` 的环境保持一致；不再以 PyTorch 版本范围作为独立
AudioEncoder 转换的阻塞条件，实际可用性以 `mtk_ptq_llm`/`mtk_converter` 的实测
结果为准。
