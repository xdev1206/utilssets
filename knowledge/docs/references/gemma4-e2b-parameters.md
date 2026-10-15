# Gemma 4 E2B 参数参考

## 结论

本文记录 Gemma PyTorch 仓库当前 `gemma/gemma4/` 实现的配置。E2B 是 35 层 dense Transformer，使用局部/全局混合注意力、每层额外的 256 维输入，以及配置驱动的视觉和音频塔。

实现位置：`gemma/gemma4/gemma4_config.py`、`gemma/gemma4/gemma4_model.py`。

## 基础参数

| 参数 | 值 | 含义 |
| --- | ---: | --- |
| `num_layers` | 35 | Transformer block 数量 |
| `num_embed` | 262,144 | 词表大小 |
| `embed_dim` | 1,536 | hidden state 维度 |
| `hidden_dim` | 6,144 | dense FFN 隐藏维度，`embed_dim * 4` |
| `num_heads` | 8 | Query attention heads |
| `head_dim` | 256 | Sliding Attention 的 Query head 维度 |
| `global_head_dim` | 512 | Full Attention 的 Query head 维度 |
| `num_kv_heads` | 1 | Local attention 的 KV heads；属于 GQA |
| 默认 dtype | `bfloat16` | 模型默认参数/计算类型 |

Sliding Query 投影维度为 `8 * 256 = 2048`；Full Query 投影维度为 `8 * 512 = 4096`；KV 投影分别为 `1 * 256` 和 `1 * 512`。

## 注意力与 RoPE

注意力模式每五层重复一次：`LOCAL, LOCAL, LOCAL, LOCAL, GLOBAL`。35 层共 28 个 Local 层和 7 个 Global 层，Global 层索引为 `4, 9, 14, 19, 24, 29, 34`。

| 参数 | 值 | 含义 |
| --- | ---: | --- |
| `sliding_window_size` | 512 | Local attention 的窗口大小 |
| `global_key_size` / `global_head_dim` | 512 | Full Attention 的 head 维度 |
| `num_global_kv_heads` | 1 | Full 层 KV heads，当前与 `num_kv_heads` 相同 |
| `local_base_frequency` | 10,000 | Sliding RoPE base frequency |
| `global_base_frequency` | 1,000,000 | Full RoPE base frequency |
| `local_rope_proportion` | 1.0 | `rotary_dim / head_dim` |
| `global_rope_proportion` | 0.25 | `rotary_dim / head_dim` |
| `local_rotary_dim` | 256 | Sliding 层完整旋转 |
| `global_rotary_dim` | 128 | Full 层仅旋转前 1/4 head |
| `attn_logits_soft_cap` | `None` | Attention logits 不做 softcap |
| `qk_norm_with_scale` | `True` | Q/K RMSNorm 带可学习 scale |

## KV Sharing

当前 PyTorch 配置为 `num_kv_shared_layers = 0`，因此不启用跨层 KV sharing；每层计算自己的 K/V 投影。

## 每层输入与输出

`per_layer_input_dim = 256` 表示每层有独立的 256 维输入。该输入会与当前层输出经过投影、GELU 门控、反投影和 RMSNorm 后，再加回 hidden state。

模型启用 `use_post_attn_norm=True` 和 `use_post_ffw_norm=True`。最终使用 RMSNorm，再通过 tied embedding 投影到词表，并应用 `final_logit_softcap=30.0`。

## 多模态与运行模式

PyTorch 实现的视觉、音频塔配置和实现分别位于 `gemma4_vision.py`、`gemma4_audio.py`；是否启用由组合模型和 checkpoint 配置决定。

## 相关实现

- [Gemma 4 model definition](https://github.com/google-deepmind/gemma/blob/main/gemma/gm/nn/gemma4/_gemma4.py)
- [Gemma 4 configuration](https://github.com/google-deepmind/gemma/blob/main/gemma/gm/nn/gemma4/_config.py)
- [Gemma 4 block and attention modules](https://github.com/google-deepmind/gemma/blob/main/gemma/gm/nn/gemma4/_modules.py)
