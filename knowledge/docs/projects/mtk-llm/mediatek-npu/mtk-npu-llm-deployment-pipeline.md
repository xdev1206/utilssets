# MTK NPU LLM 部署流水线

## 结论

MTK NPU LLM 部署可拆为 18 个可执行阶段：模型准备、校准、float 门禁、PTQ、定形、图手术、MDLA 编译、打包和设备验证。HF 与 MTK float 对齐必须先通过，不能以“编译成功”代替数值验证。

## 阶段

| 阶段 | 作用 |
|---|---|
| 0 preflight | 检查 SDK、模型、GPU、NDK、磁盘和设备工具。 |
| 1 farm | 创建 MTK config 与 HF 权重的模型 farm。 |
| 2 calib | 用真实 prompts 生成 PTQ 校准数据。 |
| 3 floatgate | HF 与 MTK float greedy 对齐；必须 PASS。 |
| 4 ptq | 逐层执行全量 PTQ，生成动态 shape TFLite。 |
| 4b rename | 隔离全量 PTQ 产物，避免 partial PTQ 覆盖。 |
| 4c ptqbin | 导出 embedding/PLE bin。 |
| 5 fixshape | 固定 prompt/gen 图形状。 |
| 5b surgery | 修复设备编译所需的 score path、mask 和 MatMul dtype。 |
| 5c cut | 切分 prompt、tail/shared-KV 图。 |
| 6 mdla | 编译 MDLA DLA 并抽取共享权重。 |
| 7 package | 打包 DLA、权重、embedding、PLE、tokenizer 和设备 yaml。 |
| 8 oracle | 在 PC 上运行量化 oracle 并与 float baseline 对比。 |
| 9 cmdtool | 应用必要补丁并编译设备 cmdline tool。 |
| 10 push | 推送 tool 和 assets 到设备。 |
| 11 device | 执行短 prompt 设备验证。 |
| 12 longctx | 执行长上下文设备验证和性能测试。 |
| 13 report | 汇总输出、性能和产物。 |

## 验证门

- float gate 使用相同 chat template、greedy 解码和至少 3 条不同类型 prompt。
- 结果必须落盘 `prompts.jsonl`、HF/MTK 输出、`comparison.md` 和 `summary.json`。
- Gemma4 `gecko4` 模型应使用支持 `bfloat16` 的 SDK，并以 `--dtype bfloat16 --pipeline-dtype bfloat16` 运行 float gate。
- 设备验证前还要依据图 I/O dtype 完成 score-path 手术；Gemma4 INT16 RoPE 需要应用 partial-rotary 补丁。
### Converter / NP8 编译器兼容性

在 Gemma4 部署中必须把 converter 与 MDLA 编译器作为一组验证：本次实测由
`mtk_converter 10.6.0` 导出的 fixed/cut 图在 `ncc-tflite 8.2.31` 上统一于
`Fail to build TFLite interpreter` 失败（ctx4096/8192/16384 均如此）。因此不能
仅因 NP8 SDK 支持 gecko4 就认为它能编译 10.6 产物；应使用与 NP8 配套的 converter
重新执行 PTQ 至 cut，或取得厂商确认的跨版本产物/编译方案后再进入 MDLA。

2026-10-22 验证了一个可复用的跨版本流程：保留 `mtk_llm_sdk 4.0.1b2` 生成的
`mtk_converter 10.6.0` 动态 PTQ 产物，在 fix-shape 阶段使用同 SDK 搭配
`mtk_converter 10.3.0` 并指定 `--np-compat 8`；之后对 PROM/GEN 图执行 score-path
INT16 手术（`fix_scorepath.py --np-compat 8`）、切 PROM 图，再用 NP8.0.11
`ncc-tflite 8.2.31` 编译 MT6899。W4A16 Gemma4-E2B-it 的 PROM/GEN DLA 编译及
`extract-shared` 均通过。该流程只验证到 MDLA 资产生成；设备未连接，因此尚未验证
设备加载和推理。

同日进一步将该流程用于 W4A16 + 外置 Embedding/PLE group64 G4LUTI4 资产：Embedding LUT
输出 INT16（与图输入 scale `0.0006681208033114672` 匹配），PLE LUT 输出 FP32（匹配图的
PLE 输入类型），Runtime YAML 分别设 `embeddingFileType: INT4`、`pleFileType: INT4`、
`pleInputType: FP32`。词表 262144 时两 LUT 文件分别为 226,492,512 B 和
1,321,205,856 B；PROM/GEN DRAM 约 330 MB / 1.1 GB。完整包已生成，含 DLA/shared sha.bin、
tokenizer 和 YAML。设备操作必须使用项目入口 `tools/adb_env.sh` 探测本机 adb server 代理端口；
经该入口曾识别到 TECNO_CO9m，并推完 cmdline tool，但设备在开始推送模型 assets 时掉线，
因此模型资产传输和实际加载/推理仍待设备恢复后完成。

ADB 反向隧道服务端脚本的默认端口是 `15037`。项目 `tools/adb_env.sh` 应优先探测
`15037`，再回退到历史端口；手动指定 `ADB_PORT=15037` 时，若隧道不可达应直接报错，
避免静默改连本机默认 `5037` adb server。
