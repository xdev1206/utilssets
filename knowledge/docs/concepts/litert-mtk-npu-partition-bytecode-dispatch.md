# LiteRT MediaTek NPU 的 Partition、Bytecode 与 DISPATCH_OP

## 核心结论

LiteRT 将模型划分为多个 partition；MediaTek compiler plugin 为每个 partition 单独生成一个 Neuron bytecode；LiteRT 再通过 `DISPATCH_OP` 将对应 bytecode 绑定到该 partition 的执行入口，手机端由 MediaTek dispatch library 和 Neuron runtime 负责加载和执行。

```text
Partition
  -> Neuron 编译
  -> Bytecode
  -> DISPATCH_OP
  -> MediaTek Dispatch
  -> Neuron Runtime
  -> NPU
```

## 关键概念

| 概念 | 含义 |
| --- | --- |
| Partition | LiteRT 切分出的可执行子图；一个 partition 可以包含多个算子 |
| Neuron compiled network | MediaTek Neuron 编译器生成的实际 NPU 网络 |
| Bytecode | 包含 compiled network、schema 和 SDK 版本信息的可加载容器 |
| BytecodeBuilder | 负责构造一个 Neuron bytecode 容器的对象 |
| `DISPATCH_OP` | LiteRT 中将一个 partition 转交给厂商后端的自定义调度算子 |
| `graph_name` | partition 的名称，例如 `Partition_0` |
| `byte_code_idx` | partition、bytecode 和模型 asset 之间的索引映射 |
| Dispatch library | 手机端读取 bytecode 并调用 Neuron API 的 LiteRT 后端库 |
| Neuron Adapter | LiteRT 与手机 Neuron runtime 之间的动态库接口 |

## 编译阶段

编译插件从 `LiteRT Model` 中逐个取得 partition：

```text
Partition_0 -> CompilePartition() -> BytecodeBuilder_0 -> Bytecode_0
Partition_1 -> CompilePartition() -> BytecodeBuilder_1 -> Bytecode_1
```

每个 partition 的处理顺序是：

1. 生成名称 `Partition_i`。
2. 取出第 `i` 个 subgraph。
3. 将 LiteRT 算子转换为 Neuron 算子。
4. 调用 Neuron compilation 生成 compiled network。
5. 创建独立的 `BytecodeBuilder`。
6. 写入 Neuron SDK 版本和当前 compiled network。
7. 调用 `Finish()` 完成当前 bytecode。
8. 保存到 `bytebuilders[i]`，并保存对应的 `graph_names[i]`。

最终映射为：

```text
bytebuilders[0] -> Partition_0 -> Bytecode_0
bytebuilders[1] -> Partition_1 -> Bytecode_1
bytebuilders[2] -> Partition_2 -> Bytecode_2
```

一个 partition 对应一个 bytecode，但一个 partition 内仍然可以包含多个神经网络算子；这里不是一个算子对应一个 bytecode。

## LiteRT 模型绑定阶段

编译结果返回给 LiteRT 后，LiteRT 会：

1. 查询 bytecode module 数量。
2. 按 index 读取每个 bytecode。
3. 将 bytecode 注册为模型 asset。
4. 查询每个 dispatch call 的 `graph_name` 和 `byte_code_idx`。
5. 将正确的 asset 绑定到对应的 `DISPATCH_OP`。

例如：

```text
DISPATCH_OP_0 -> graph_name=Partition_0 -> bytecode_0
DISPATCH_OP_1 -> graph_name=Partition_1 -> bytecode_1
```

因此，`DISPATCH_OP` 不是普通的 Gemma 算子，也不是 Neuron 算子，而是 LiteRT 图到 MediaTek NPU 执行网络之间的桥接入口。

## 手机运行阶段

手机端执行某个 `DISPATCH_OP` 时，MediaTek dispatch library 会：

1. 读取该 op 附加的 bytecode asset。
2. 通过 Neuron schema 解析 bytecode。
3. 根据 `graph_name` 找到 compiled graph。
4. 检查 bytecode 中记录的 Neuron SDK 版本。
5. 读取 compiled network。
6. 创建 `NeuronModel`、`NeuronCompilation` 和 `NeuronExecution`。
7. 调用 Neuron runtime 在 NPU 上执行。

## 为什么采用“一 Partition 一 Bytecode”

旧设计将多个 partition 放进同一个 `BytecodeBuilder`：

```text
Partition_0 + Partition_1 + Partition_2
              -> 一个超大的 Bytecode container
```

对于 Gemma4 等大模型，单个 compiled-network/container 可能超过 Neuron runtime 的约 2 GiB 限制，导致编译完成、封装失败或手机加载失败。

新设计将其拆开：

```text
Partition_0 -> Bytecode_0
Partition_1 -> Bytecode_1
Partition_2 -> Bytecode_2
```

这样可以限制单个 Neuron container 的大小，同时保持每个 dispatch op 与其 partition 的一一对应关系。

## 常见错误的含义

```text
unresolved custom op: DISPATCH_OP
```

通常表示 LiteRT 没有成功找到或初始化 `DISPATCH_OP` 的处理后端，常见原因包括：

- MediaTek dispatch library 未加载；
- Neuron Adapter 路径或版本不匹配；
- bytecode schema 或 compiled network 无法解析；
- Neuron compilation 初始化失败；
- dispatch op 没有正确绑定 bytecode asset。

该错误通常是 NPU backend 初始化失败后的表现，不一定表示模型缺少普通算子。

## 源码对应关系

- MediaTek compiler plugin：`LiteRT/litert/vendors/mediatek/compiler/compiler_plugin.cc`
- Neuron 模型构造：`LiteRT/litert/vendors/mediatek/compiler/create_model.cc`
- Neuron 编译：`LiteRT/litert/vendors/mediatek/compiler/compile_model.cc`
- LiteRT bytecode 注册和 dispatch 绑定：`LiteRT/litert/compiler/plugin/compiler_plugin.cc`
- 手机端 bytecode 解析和执行：`LiteRT/litert/vendors/mediatek/dispatch/litert_dispatch_invocation_context.cc`
- Neuron schema 解析：`LiteRT/litert/vendors/mediatek/schema/schema_resolver.h`

## 验证范围

本文描述的是 LiteRT MediaTek compiler plugin 的 AOT 编译和 dispatch 数据流。它解释 bytecode 如何生成、绑定和加载，不代表某个具体 SoC、Neuron SDK 或手机固件已经通过端到端运行验证。
