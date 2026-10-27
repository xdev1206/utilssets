# MediaTek `mtk_quantization` 通用量化包参考

本文依据 SDK 10.0.0 安装源码与 SDK 9.0.1+amp 对照，分析 `mtk_quantization` Python 库本身的 API。它是通用的 PyTorch / TensorFlow 量化感知训练（QAT）库；`mtk_ptq_llm` 的 Gemma 配置和 `-w hessian/gradient` 属于上层 LLM SDK 工作流，不是本文讨论的包内量化器算法。

## 安装与可导入环境

- 当前默认 Python `/workspace/xin.xu5/utilssets/tools/pyenv/versions/3.12.14/bin/python` 中未安装该包。
- SDK 10.0.2 专用 Python 环境可导入 `mtk_quantization`，模块版本为 `10.0.0`；SDK 9 的共享环境可导入 `9.0.1+amp`。NP10 和 NP8 离线 SDK 目录也保留对应 wheel。
- SDK 10 环境装有 PyTorch，可用 `mtk_quantization.pytorch` API。TensorFlow v1/v2 的模块源码也在包里，但实际调用仍需安装相应 TensorFlow 版本。

## 包的功能层次

| 后端 | 对外入口 | 主要用途 |
|---|---|---|
| PyTorch | `mtk_quantization.pytorch` | 生成量化配置、将浮点模块转换为 QAT 模块；提供功能算子与模块融合 |
| TensorFlow v1 | `mtk_quantization.tfv1` | graph/frozen graph 配置生成、QAT graph 准备、Estimator 集成 |
| TensorFlow v2 | `mtk_quantization.tfv2.keras` | Keras Sequential/Functional 配置生成与 QAT 模型准备 |

三个后端均有 `ConfigGenerator`、`QuantizeHandler` 和相同命名的量化器家族。典型流程是：分析模型并导出量化配置 → `QuantizeHandler.prepare(...)` 插入 fake-quant/QAT 模块 → 校准/训练 → 由框架或后续 converter 完成目标格式转换。`prepare` 是 QAT 模型准备 API，不会直接写出已打包的 INT4/INT8 权重文件。

## 核心量化器

`mtk_quantization.pytorch.quantizers` 导出以下量化器；TFv1 与 TFv2/Keras 有对应实现：

| 类 | min/max 范围来源 | 适用方式 |
|---|---|---|
| `AllValuesQuantizer` | 累计已处理 batches 的整体 min/max | 多批数据累计范围 |
| `LastValueQuantizer` | 最近一个 batch 的 min/max | 用最新 batch 刷新范围 |
| `EMAQuantizer` | 跨 batch 对 min/max 做指数滑动平均 | 平滑随训练变化的激活范围 |
| `MSEOptQuantizer` | 优化量化误差来求 min/max | 用量化误差目标调整范围 |
| `LogTholdQuantizer` | QAT 中训练 `log2thold`；对称时范围为 `[-2^t, 2^t]` | 学习阈值，构造适合幂次缩放的范围 |
| `ConstantQuantizer` | 用户提供的固定 min/max | 固定校准范围/常量范围 |
| `UnionQuantizer` | 一个或多个来源量化器范围的并集 | 对齐 Add/Concat/平均池化等合并路径的范围 |

`ConfigGenerator` 默认权重量化器为 `LastValueQuantizer`，激活为 `EMAQuantizer`；PyTorch 参数量化器（如 PReLU alpha）默认也是 `LastValueQuantizer`。它允许用户为权重、参数、激活分别指定前六种；`UnionQuantizer` 由图分析按依赖关系处理，不在默认 quantizer type 选择器中。

这些类实现的是范围估计或学习策略；实际量化还由 bitwidth、对称/非对称设置、per-tensor/per-channel 轴和 fake-quant 算子共同决定。

## 可设置的量化参数

PyTorch/Keras `ConfigGenerator` 暴露以下主要选项：

- `weights_bitwidth`、`activations_bitwidth`、PyTorch 的 `params_bitwidth`。量化配置 schema 对 bitwidth 允许 2–16 bit。
- `use_weights_symmetric_quantization`、`use_activations_symmetric_quantization`、`use_params_symmetric_quantization`。
- `use_per_output_channel_quantization`：权重按输出通道量化；关闭时使用 per-tensor 范围。
- `weights_quantizer_type`、`activations_quantizer_type`、`params_quantizer_type`：选择上文量化器。
- `use_power_of_two_quantization_scale`，以及 scale 的 `RoundUp` / `RoundDown` / `RoundNearest` 规则。
- `ignore_union_quantizer_targets`：不为需要合并范围的目标生成 UnionQuantizer。

这套 API 用独立 bitwidth 和 bool 开关描述量化。它与 LLM SDK precision JSON 中的 `sym4W_sym16A` 等字符串、`int4/int8` 简写是不同层次的接口，不能直接混用。

## PyTorch 示例：生成配置并准备 QAT 模型

```python
import torch
from torch import nn
from mtk_quantization.pytorch import ConfigGenerator, QuantizeHandler

model = nn.Sequential(nn.Linear(16, 8), nn.ReLU(), nn.Linear(8, 4))

config = ConfigGenerator(model)
config.weights_bitwidth = 8
config.activations_bitwidth = 8
config.use_weights_symmetric_quantization = True
config.use_activations_symmetric_quantization = False
config.weights_quantizer_type = "MSEOptQuantizer"
config.activations_quantizer_type = "EMAQuantizer"
config.use_per_output_channel_quantization = True
config.export_config("quant_config.json", example_inputs=torch.randn(1, 16))

handler = QuantizeHandler()
qat_model = handler.prepare(model, "quant_config.json")
```

`export_config` 需要 `example_inputs`：该默认配置会追踪 activation 的依赖关系，以设置 `UnionQuantizer` 来源。`prepare` 返回替换了可支持层的 QAT 模型，并在前向传播时模拟量化；接下来仍由调用方执行训练/校准循环。权重量化器可改为 `LastValueQuantizer`、`AllValuesQuantizer`、`EMAQuantizer`、`LogTholdQuantizer` 或 `ConstantQuantizer`。

直接调用单个 fake-quant 量化器的示例：

```python
import torch
from mtk_quantization.pytorch.quantizers import EMAQuantizer

q = EMAQuantizer(init_bitwidth=8, init_symmetric=False)
y = q(torch.randn(2, 16))
```

这会在 PyTorch 图中模拟量化和更新范围；它本身不会把模型参数打包成 INT8 文件。

## TensorFlow 示例

TensorFlow v2/Keras 对 Sequential/Functional 模型提供同类入口：

```python
from mtk_quantization.tfv2.keras import ConfigGenerator, QuantizeHandler

config = ConfigGenerator(keras_model)
config.weights_bitwidth = 8
config.activations_bitwidth = 8
config.weights_quantizer_type = "LastValueQuantizer"
config.activations_quantizer_type = "EMAQuantizer"
config.export_config("keras_quant_config.json")

qat_model = QuantizeHandler().prepare(keras_model, "keras_quant_config.json")
```

TensorFlow v1 入口 `mtk_quantization.tfv1` 支持从 frozen graph / SavedModel 建立 `ConfigGenerator`，并提供 `tfv1.estimator.prepare_model_fn` 将 QAT 准备过程接入 Estimator。具体图名、输入形状和 TensorFlow 版本需与对应模型匹配。

## 其他 PyTorch API 与版本差异

- `mtk_quantization.pytorch.functional` 提供 `Add`、`Cat`、`Div`、`Matmul`、`Mul`、`Sub`、`QuantizerStub`，用于函数式计算路径上的量化/QAT 算子。
- PyTorch QAT 模块覆盖常见 Linear、Conv/ConvTranspose、BatchNorm、PReLU 和部分 merge 层；具体可替换层见 `pytorch/defs.py`。
- `QuantizeHandler` 提供 `freeze_all_quantizers()`、`disable_all_quantizers()` 等控制：freeze 停止更新量化范围，disable 暂时旁路 fake quant。
- SDK 9.0.1+amp 还带实验性 GIS mixed-precision handler；检查到的 SDK 10.0 安装没有该 mixed-precision 子目录，不应假设该实验 API 在 10.0 可用。
- `mtk_quantization` 的 quantizer 名称不是 PTQ 权重优化方法名。`hessian`/`gradient` 是上层 LLM PTQ 工具的优化选项，不是这七种量化器类；AWQ/GPTQ 也不在该通用包公开的量化器列表中。

源码位置：NP10 SDK 的 `site-packages/mtk_quantization/{pytorch,tfv1,tfv2}`；常见量化器默认值见 `pytorch/config_utils.py` 与 `pytorch/quantizers/`。LLM SDK 的精度字符串和部署配方由上层 SDK 管理，不属于本文包内 API。
