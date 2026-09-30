# Gemma 4 E2B 参数参考

## 结论

本文记录仓库当前 `gm.nn.Gemma4_E2B` 的配置。E2B 是 35 层 dense Transformer，默认以文本模式运行；它使用局部/全局混合注意力、跨层 KV cache sharing，以及每层额外的 256 维输入。

实现位置：`gemma/gm/nn/gemma4/_gemma4.py` 的 `Gemma4_E2B`。

## 基础参数

| 参数 | 值 | 含义 |
| --- | ---: | --- |
| `num_layers` | 35 | Transformer block 数量 |
| `num_embed` | 262,144 | 词表大小 |
| `embed_dim` | 1,536 | hidden state 维度 |
| `hidden_dim` | 6,144 | dense FFN 隐藏维度，`embed_dim * 4` |
| `num_heads` | 8 | Query attention heads |
| `head_dim` | 256 | 每个 Query head 的维度 |
| `num_kv_heads` | 1 | Local attention 的 KV heads；属于 GQA |
| 默认 dtype | `bfloat16` | 模型默认参数/计算类型 |

Query 投影维度为 `8 * 256 = 2048`；Local KV 投影维度为 `1 * 256 = 256`。

## 注意力与 RoPE

注意力模式每五层重复一次：`LOCAL, LOCAL, LOCAL, LOCAL, GLOBAL`。35 层共 28 个 Local 层和 7 个 Global 层，Global 层索引为 `4, 9, 14, 19, 24, 29, 34`。

| 参数 | 值 | 含义 |
| --- | ---: | --- |
| `sliding_window_size` | 512 | Local attention 的窗口大小 |
| `global_key_size` | 512 | Global attention 的 Key 维度 |
| `num_global_kv_heads` | `None` | Global 层回退使用 `num_kv_heads=1` |
| `local_base_frequency` | 10,000 | Local RoPE 基频 |
| `global_base_frequency` | 1,000,000 | Global RoPE 基频 |
| `local_rope_proportion` | 1.0 | Local RoPE 比例 |
| `global_rope_proportion` | 0.25 | Global RoPE 比例 |
| `k_eq_v_global` | `False` | Global 层不共用 K/V 投影 |
| `attn_logits_soft_cap` | `None` | Attention logits 不做 softcap |
| `qk_norm_with_scale` | `True` | Q/K RMSNorm 带可学习 scale |

## KV Cache Sharing

`frac_shared_layers = 20 / 35`，因此 20 层使用共享 KV 访问模式，前 15 层保持非共享。`share_global=True` 和 `share_local=True` 分别允许 Global/Local 层复用对应的 KV cache。映射规则在 `gemma/gm/nn/gemma4/_config.py` 的 `create_kv_cache_sharing_patterns()` 中实现：后续 Local 层复用 `layer_13` 的 KV，后续 Global 层复用 `layer_14` 的 KV。

共享层并不会跳过完整 Transformer block。每个共享层仍然计算自己的 Query、Attention、FFN、残差和 per-layer input；但 Attention 使用代表层的 K/V：

```text
Q_i = x_i Wq_i
Attention_i = softmax(Q_i K_shared.T + mask_i) V_shared
```

当前实现仍会先执行共享层自身的 K/V 投影，随后用 `kv_shared_cache['k']` 和 `kv_shared_cache['v']` 覆盖结果，因此这些本层 K/V 不参与 Attention。源码中的 TODO 表明，未来 checkpoint 可能移除共享层中不再需要的 K/V 投影参数。代表层负责计算并更新实际使用的共享 cache；Local 和 Global 层分别使用对应的注意力 mask。

该机制减少的是逻辑上的独立 KV cache 和 KV 访问，不等于跳过后 20 层的 Attention 计算。当前 `init_cache()` 仍按层初始化 cache 字典；最终内存是否减少，还取决于后端是否对共享 cache 做合并或别名优化。

共享 KV 的层使用 `override_kv_shared_ffw_hidden = 12,288`，即普通 FFN 隐藏维度的两倍，用于补偿共享层的容量变化。

## 每层输入与输出

`per_layer_input_dim = 256` 表示每层有独立的 256 维输入。该输入会与当前层输出经过投影、GELU 门控、反投影和 RMSNorm 后，再加回 hidden state。

模型启用 `use_post_attn_norm=True` 和 `use_post_ffw_norm=True`。最终使用 RMSNorm，再通过 tied embedding 投影到词表，并应用 `final_logit_softcap=30.0`。

## 多模态与运行模式

配置包含 `VisionEncoder(use_clipped_linears=True)` 和默认 `ConformerConfig()` 音频编码器，但 `_Gemma4Base.text_only` 默认是 `True`。因此 `Gemma4_E2B()` 默认移除视觉和音频 encoder；使用 `text_only=False` 才保留多模态模块。

`use_bidirectional_attention=None`，表示 E2B 文本 backbone 全部使用 causal attention。模型信息中的 tokenizer version 为 4。

## 相关实现

- [Gemma 4 model definition](https://github.com/google-deepmind/gemma/blob/main/gemma/gm/nn/gemma4/_gemma4.py)
- [Gemma 4 configuration](https://github.com/google-deepmind/gemma/blob/main/gemma/gm/nn/gemma4/_config.py)
- [Gemma 4 block and attention modules](https://github.com/google-deepmind/gemma/blob/main/gemma/gm/nn/gemma4/_modules.py)
