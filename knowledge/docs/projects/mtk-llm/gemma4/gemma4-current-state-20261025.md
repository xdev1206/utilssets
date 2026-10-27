# Gemma4 当前项目状态与统一术语（2026-10-25）

本文记录截至 2026-10-25 的项目状态快照。新实验的结果以对应日期记录和原始日志为准；
本页负责当前配置、质量门禁结论和待办概览。

## 当前模型与环境

```text
模型：/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it
环境：/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
平台：MT6897/MT6899 目标设备，NP8，MDLA；当前 INT4 验证使用 NP8
词表：262144
Embedding：262144×1536，原始 BF16
PLE：262144×8960，原始 BF16
```

## 当前 PTQ 与 Runtime 契约

当前验证目标使用完整词表、group64、Embedding/PLE 逻辑 INT4、PTQ INT8 中间容器和
Runtime INT16。配置中 `default=sym4W_sym16A` 产生 PLE 的
`FLOAT32 → QUANTIZE → INT16` 图边界；YAML 的 `pleInputType=INT16` 只匹配设备 buffer。

- 字段及激活精度边界：[PLE activation 精度说明](gemma4-ple-default-activation-precision.md)。
- G4LUTI4 文件、打包和 Runtime 规则：[格式与 Runtime 契约](../runtime/gemma4-external-lut-g4luti4-int4.md)。
- 2026-10-25 设备数据：[端侧验证与比较](gemma4-device-validation-results-20261025.md)。
- 该日期的完整 assets 清单：[部署产物索引](gemma4-deployment-artifacts-20261025.md)。

## 当前验证结论

- Host PTQ、fix-shape、score-path surgery、PROM cut、NP8/MT6897 MDLA 编译、shared
  提取、G4LUTI4 打包和 assets 推送均已完成。
- 设备 INT4/INT4 包 t0–t6：7/7 `rc=0`，无 SIGSEGV；但输出存在乱码、重复 token 或
  错误语言，语义质量判定 FAIL。原始数据：
  `verify_logs/device_embint4_pleint4_int16_nohessian_np8_ctx4096_20261025/`。
- 同一 runtime 的历史 Embedding INT8 + PLE INT16 对照也为 7/7 `rc=0`，但同样语义
  FAIL：`verify_logs/device_embint8_compat_control_np8_ctx4096_20261025/`。
- 当前结论是“加载/执行门禁通过，质量门禁未通过”；不能把 `rc=0` 当作精度通过。
- 当前 x86 oracle 能生成正常文本，但其外部 embedding 不是 Android G4LUTI4 runtime
  的直接验证，因此还需要对 INT4→INT16 物理数值与图 scale 做 bit-exact 以及设备质量
  回归。

## 文档优先级和历史记录规则

1. 当前配置、类型链路和阻塞项：本文。
2. PLE activation 机制：[default activation 与 INT16 边界](gemma4-ple-default-activation-precision.md)。
3. G4LUTI4 文件布局与 Runtime 解码：[runtime 格式契约](../runtime/gemma4-external-lut-g4luti4-int4.md)。
4. 实验命令和逐条输出：对应 `verify_logs/`，项目实验记录只作索引和解释。
5. 早期 PLE FP32、直接 PLE INT16 promotion、旧资产路径都是历史实验，不得作为当前
   目标配置或验收结论；保留它们是为了复现和比较。

## 下一步

采用历史 INT8 的机制重新生成 INT4 PLE 图/资产：保留 `default=sym4W_sym16A` 产生的
`FLOAT32 → QUANTIZE → INT16` 边界，停用直接 PLE INT16 promotion，先验证固定图的
tensor dtype、scale、INT4 解码 bit-exact，再重新 cut/MDLA/设备验证。Embedding INT8
控制包必须先回归通过，确保新 Runtime 同时兼容 INT8 与 INT4。
