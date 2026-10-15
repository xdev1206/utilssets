# Gemma4 PTQ 量化配置参考

适用环境：`mtk_llm_sdk 4.0.1b2.post1.dev125`。本文记录 Gemma4 PTQ 配置字段、精度字符串和已在 NP8 流程中使用的组合。

## 精度字符串

格式为 `<weight scheme><weight bits>W_<activation scheme><activation bits>A`。

例如 `sym8W_sym16A` 表示 8-bit 对称权重、16-bit 对称激活；`asym4W_sym16A` 表示 4-bit 非对称权重、16-bit 对称激活。

常用组合：

| 字符串 | 含义 |
|---|---|
| `sym4W_sym16A` | 对称 4-bit 权重，对称 16-bit 激活 |
| `asym4W_sym16A` | 非对称 4-bit 权重，对称 16-bit 激活 |
| `sym8W_sym16A` | 对称 8-bit 权重，对称 16-bit 激活 |
| `sym4W_sym8A` | 对称 4-bit 权重，对称 8-bit 激活 |
| `sym8W_sym8A` | 对称 8-bit 权重，对称 8-bit 激活 |
| `FP` | 浮点，不量化 |
| `dynamic_quant` | 动态量化 |

`sym` 表示对称量化，`asym` 表示非对称量化，`asymU` 表示无符号非对称量化；`W` 是权重，`A` 是激活。

SDK 还支持 2/3/4/5/6/7/8/16-bit 权重的更多组合，但能通过 SDK 解析不等于一定适合 Gemma4 NP8/MDLA，必须经过 x86、编译和设备验证。

## 配置字段

```json
{
  "llm": {},
  "tail": "...",
  "default": "...",
  "softmax": "...",
  "res_path": "...",
  "embeddings": "...",
  "logits": "...",
  "cache": "..."
}
```

| 字段 | 作用 |
|---|---|
| `llm` | 各层 Attention/MLP 投影的权重精度 |
| `tail` | 最后的 lm_head/tail 层精度 |
| `default` | 默认激活精度 |
| `softmax` | Softmax 精度 |
| `res_path` | Transformer 残差路径精度 |
| `embeddings` | 输入 embedding 精度 |
| `logits` | 最终 logits 输出精度 |
| `cache` | KV cache 精度 |
| `mask` | Attention mask 精度 |
| `ple` | Per-layer embedding 精度 |
| `bypass` | 跳过量化的算子列表 |

Gemma4 的 `llm` 层可按 `0-34` 或具体模块配置：`q`、`k`、`v`、`o`、`gate`、`up`、`down`，也支持 `attention`/`mlp` 整体配置。

## standalone 简写

SDK 接受 `int4`、`int8`、`int16`、`float`，其映射不是同 bit 的 W/A 配置：

| 简写 | 实际映射 |
|---|---|
| `int4` | `sym4W_sym4A` |
| `int8` | `sym4W_sym8A` |
| `int16` | `sym4W_sym16A` |
| `float` | `FP` |

因此 `"embeddings": "int8"` 实际表示 `sym4W_sym8A`，不是 `sym8W_sym8A`。

## 当前 Gemma4 NP8 推荐起点

已使用或验证过的优先组合：

```text
sym4W_sym16A
sym8W_sym16A
sym4W_sym8A
asym4W_sym16A
FP
int8
int16
float
```

参考配置：

- `/workspace/xin.xu5/projs/gemma_projs/gemma4/mtk-npu-llm-deploy/configs/gemma4/gemma4_precision_config.json`
- `/workspace/xin.xu5/projs/gemma_projs/gemma4/mtk-npu-llm-deploy/configs/gemma4/quant_w4e16_tailw8_embint8_resw8.json`

来源：`mtk_quantization/common/precision_utils.py` 和 `mtk_llm_sdk/utils/precision_config.py`。

## 动态量化配置

项目中的 `configs/gemma4/quant_dynamic.json` 是动态量化起始配置：

```json
{
  "llm": {"0-34": "dynamic_quant"},
  "tail": "dynamic_quant",
  "default": "dynamic_quant",
  "softmax": "float",
  "res_path": "dynamic_quant",
  "embeddings": "dynamic_quant",
  "logits": "float",
  "cache": "int8"
}
```

在当前 SDK 中，`dynamic_quant` 解析为 8-bit 权重、FP32 动态激活（`int8, float`），不是静态 INT8 激活，也不是全 FP。`cache: int8` 单独保留 KV cache 的 INT8 存储格式；动态量化配置仍需经过 x86、NP8 编译和设备验证，不能仅凭配置解析成功判定可部署。
