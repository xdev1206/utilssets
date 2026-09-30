# LiteRT MediaTek NPU Partition 切分与 DISPATCH_OP 连接逻辑

## 核心结论

LiteRT 的 partition 切分由通用 compiler plugin 框架完成。MediaTek plugin 负责选择可由 NPU 编译的算子；LiteRT 再根据算子顺序和数据依赖将它们分组，复制到新的 subgraph，并在原主图中用 `DISPATCH_OP` 替换原来的算子区域。

```text
MTK plugin 选择算子
    ↓
LiteRT 分组 partition
    ↓
复制到新 Subgraph
    ↓
主图插入 DISPATCH_OP
    ↓
MTK compiler 编译 Subgraph
    ↓
Neuron Bytecode
```

## 1. MTK plugin 选择可编译算子

入口位于：

```text
LiteRT/litert/vendors/mediatek/compiler/compiler_plugin.cc
LiteRtCompilerPluginPartition()
```

该函数检查主图中的每个算子：

```text
支持的算子   → selected_ops
不支持的算子 → 留在 CPU/其他后端
```

这一步只回答“哪些算子可以交给 MTK NPU”，还没有真正创建 partition。

## 2. LiteRT 将 selected ops 分组成 partition

入口位于：

```text
LiteRT/litert/compiler/plugin/compiler_plugin.cc
PartitionSubgraph()
```

默认策略使用 `GroupPartitionsV2()`，备用策略为 `GroupPartitions()`。

分组主要依据：

- LiteRT subgraph 中的执行顺序；
- 算子对应的 partition index；
- 算子之间的 Tensor 数据依赖；
- 是否属于同一个连续或连通的 NPU 区域。

例如：

```text
op0 → op1 → op2 → cpu_op → op5 → op6
```

可能得到：

```text
Partition_0 = op0 → op1 → op2
Partition_1 = op5 → op6
```

一个 partition 是一段子图，不是一个单独算子。

## 3. 创建新的 Subgraph

每个 partition 通过 `OutlinePartition()` 从主图切出：

```text
LiteRT/litert/compiler/plugin/algo.cc
OutlinePartition()
GraphSlicer::SlicePartitionFromGraph()
```

切分过程如下：

1. 创建一个空的目标 subgraph。
2. 找出 partition 使用的输入 Tensor。
3. 将输入 Tensor 复制到新 subgraph。
4. 复制 partition 内的算子和输出 Tensor。
5. 建立“原 Tensor → 新 Tensor”的映射。
6. 将新 subgraph 的输入和输出登记完整。

示例：

```text
原主图区域：

Input → op0 → op1 → Output

新 Subgraph_0：

Input' → op0' → op1' → Output'
```

## 4. Tensor 映射与输入重连

切分不能只复制算子，还必须复制 Tensor 的边界关系。

如果 partition 使用主图输入 Tensor：

```text
主图 Input → op0
```

则：

```text
Subgraph_0：Input' → op0'
主图：     Input  → DISPATCH_OP_0
```

相关逻辑：

```cpp
AttachInput(old_tensor, *dispatch_op_);
```

这表示主图原有的输入 Tensor 被接到 `DISPATCH_OP`，同时也成为新 subgraph 的输入。

常量 Tensor 不按照普通动态输入处理，而是作为模型常量复制或保留。

## 5. Tensor 映射与输出重连

如果 partition 的输出还被主图后续算子使用：

```text
op1 → Tensor_Y → op3
```

切分后变为：

```text
Subgraph_0：op0' → op1' → Tensor_Y'

主图：      DISPATCH_OP_0 → Tensor_Y → op3
```

相关逻辑：

```cpp
AttachOutput(old_tensor, *dispatch_op_);
slice_->Outputs().push_back(new_tensor);
```

含义是：

- 新 subgraph 将 `new_tensor` 作为输出；
- 主图中的 `DISPATCH_OP` 重新成为原输出 Tensor 的产生者；
- 主图后续算子继续使用原来的 Tensor 名义和连接关系。

## 6. 用 DISPATCH_OP 替换原始算子区域

完成复制和 Tensor 映射后，原 partition 中的算子会从主图删除：

```cpp
Drop(*op);
```

随后将一个节点改造成 `DISPATCH_OP`：

```cpp
MakeDispatchOp(*dispatch_op_);
```

主图从：

```text
Input → op0 → op1 → op2 → op3 → Output
```

变为：

```text
Input → DISPATCH_OP_0 → op3 → Output
```

`DISPATCH_OP_0` 不是实际数学算子，而是原 partition 在主图中的代理节点，表示“运行到这里时调用对应的 NPU 子图”。

## 7. 清理和拓扑排序

切分后会执行：

```cpp
DCE(root);
TopologicalSort(root);
```

作用是：

- 删除不再使用的旧算子和 Tensor；
- 清理切分产生的无效节点；
- 修复主图的拓扑执行顺序。

## 8. 多个 Partition 的结果

如果模型有多个 NPU 区域：

```text
Partition_0 = op0 → op1
Partition_1 = op5 → op6
Partition_2 = op9
```

则会产生：

```text
主图：

DISPATCH_OP_0 → CPU_op → DISPATCH_OP_1 → CPU_op2 → DISPATCH_OP_2

新 Subgraph：

Subgraph_0 → Partition_0
Subgraph_1 → Partition_1
Subgraph_2 → Partition_2
```

`PartitionResult` 包含两部分：

```text
dispatch_ops：主图中的 DISPATCH_OP 列表
sliced_model：切出来、等待 vendor compiler 编译的 subgraph 模型
```

## 9. Subgraph 与 Neuron Bytecode 的关系

切分完成后，才进入 MTK 编译：

```text
Subgraph_0 → CompilePartition() → Bytecode_0
Subgraph_1 → CompilePartition() → Bytecode_1
Subgraph_2 → CompilePartition() → Bytecode_2
```

之后 LiteRT 建立：

```text
DISPATCH_OP_0 → Bytecode_0
DISPATCH_OP_1 → Bytecode_1
DISPATCH_OP_2 → Bytecode_2
```

绑定依靠：

- `graph_name`，例如 `Partition_0`；
- `byte_code_idx`，例如 `0`；
- dispatch op 附加的模型 asset。

## 10. 完整数据流

```text
原始 LiteRT 主图
    ↓
MTK plugin 选择支持的算子
    ↓
GroupPartitionsV2() 分组
    ↓
OutlinePartition() 复制算子和 Tensor
    ↓
主图原区域替换为 DISPATCH_OP
    ↓
新 Subgraph 交给 MTK compiler
    ↓
Neuron Bytecode
    ↓
绑定到对应 DISPATCH_OP
    ↓
手机端 Dispatch Library 读取并调用 Neuron Runtime
```

## 11. 核心区别

```text
MTK plugin 选择算子
    ≠
LiteRT partition 分组
    ≠
GraphSlicer 切出 Subgraph
    ≠
Neuron compiler 生成 Bytecode
```

对应源码职责：

| 功能 | 代码位置 |
| --- | --- |
| 选择 MTK 支持算子 | `LiteRT/litert/vendors/mediatek/compiler/compiler_plugin.cc` |
| Partition 总入口 | `LiteRT/litert/compiler/plugin/compiler_plugin.cc:PartitionModel()` |
| Partition 分组 | `LiteRT/litert/compiler/plugin/compiler_plugin.cc:PartitionSubgraph()` |
| 分组算法 | `LiteRT/litert/compiler/plugin/algo.cc:GroupPartitionsV2()` |
| 复制和切出 Subgraph | `LiteRT/litert/compiler/plugin/algo.cc:GraphSlicer` |
| 主图 Tensor 重连 | `GraphSlicer::RerouteTensorsThroughCustomOp()` |
| Neuron 编译 | `LiteRT/litert/vendors/mediatek/compiler/compile_model.cc` |

## Review 关注点

- “一个 partition 对应一个 bytecode”属于编译结果封装逻辑，不改变 partition 的切分算法。
- `DISPATCH_OP` 是主图中的代理节点，不是普通数学算子。
- 主图与 subgraph 的连接依靠 Tensor 输入输出边，不是简单的 op 列表拼接。
- 一个 partition 可以包含多个 LiteRT 算子。
- 本文描述的是 LiteRT/MTK AOT 数据流，不代表某个具体 SoC 和手机固件已完成端到端验证。
