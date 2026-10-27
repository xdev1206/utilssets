# Gemma4 INT4 部署历史（2026-10-23 至 25）

本文按时间保留 INT4 接入、PTQ、设备验证中的历史状态和更正，不作为当前状态入口。
当前门禁见[项目状态快照](gemma4-current-state-20261025.md)，10-25 设备结果见
[端侧验证报告](gemma4-device-validation-results-20261025.md)。

## 2026-10-23 阶段结论

已完成原始模型核对、目标 Python/MTK 环境、无 Hessian PTQ、NP8 ctx4096 fix-shape、
surgery、PROM cut、MDLA 编译和手机端执行链路验证。

必须区分两个产物：

- `assets_gemma-4-E2B-it_np8_ctx4096_20261022_int16_embedded`：稳定性 fallback，
  Embedding/PLE 为 INT16，不是最终目标。
- `assets_gemma4_w4a16_embint4_pleint4_group64_np8_20261022`：已有真实 G4LUTI4
  INT4 文件；本次 PTQ 目标保持 PLE INT4 -> FP32，旧 YAML 的设备接口仍需重新验收。

当前准确状态：**INT4 文件和打包链路已有；本次 PLE INT4 -> FP32 runtime 接口的最终设备验收未完成。**

## 原始模型和词表

原始模型：

```text
/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it
```

关键文件：`config.json`、`tokenizer.json`、`tokenizer_config.json`、`model.safetensors`。

原始配置和权重核对结果：

```text
text_config.vocab_size                 = 262144
text_config.vocab_size_per_layer_input = 262144

model.language_model.embed_tokens.weight
  [262144, 1536], bfloat16

model.language_model.embed_tokens_per_layer.weight
  [262144, 8960], bfloat16
```

`8960 = 35 * 256` 是 PLE 特征宽度，不是词表大小。Embedding 和 PLE vocabulary size
均为 `262144`。

原始 `tokenizer.json` 是 BPE，`model.vocab` 有 262144 项，另有 24 个 added tokens；
added token ID 已在 `0..262143` 范围内，不能再加到词表大小上。

裁剪模型另在：

```text
/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it_embedding-pruning
```

裁剪模型词表为 `122857`，但本次稳定 INT16 包和已有 INT4 包都使用完整 `262144` 词表。

## 环境

```text
G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
```

环境入口：`scripts/deploy/gemma4_v2/00_env.sh`。

```bash
export G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
source scripts/deploy/gemma4_v2/00_env.sh
python3 -c 'import sys,mtk_converter; print(sys.executable); print(mtk_converter.__version__); print(mtk_converter.__file__)'
"$G4_PYTHON_ENV/bin/mtk_ptq_llm" --help
```

已验证：

```text
mtk_converter 10.6.0
mtk_llm_sdk   4.0.1b2.post1.dev125+g10d6b0ede
mlkits        10.4.9
torch         2.14.1+cu130
numpy         1.26.4（按要求不作为阻塞）
```

匹配 wheel：

```text
/workspace/xin.xu5/neuropilot_env/neuropilot-sdk-premium-10.0.2-build20260826/offline_tool/mtk_converter-10.6.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

`merge_fresh500_and_ptq.sh` 已移除旧 Conda/PYTHONPATH 硬编码，改用公共环境入口。

## PTQ、NP8 和 MDLA

无 Hessian PTQ：

```bash
export G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
source scripts/deploy/gemma4_v2/00_env.sh
bash scripts/deploy/gemma4_v2/1_make_ptq_calibration_dataset.sh
bash scripts/deploy/gemma4_v2/2_ptq.sh
```

PTQ 产物示例：

```text
work/gemma4_e2b_it/quantized_models/dynamic_shape/gemma-4-E2B-it_gemma4_precision_config_Overall
```

35 个 decoder layer 和 tail 完成，`Weight optimization: None`。

NP8 工具链：

```text
neuropilot-sdk-premium-8.0.11-build20260211
ncc-tflite 8.2.31
SoC MT6899, ctx4096
```

```bash
bash scripts/deploy/gemma4_v2/8_multictx_np8.sh 4096 fix
bash scripts/deploy/gemma4_v2/5_build_mdla.sh all
```

流程包括 fix-shape、score-path surgery、PROM cut、PROM/GEN MDLA compile/extract。

## INT4 目标设计和产物

```text
Embedding [262144,1536] BF16
  -> group64 q4 / G4LUTI4 -> INT4 文件 -> runtime 输出 INT16

PLE [262144,8960] BF16
  -> group64 q4 / G4LUTI4 -> INT4 文件 -> runtime 输出 INT16
```

已有文件：

```text
work/gemma4_e2b_it/embedding_int4_v1_group64_20261021/embedding_int4.bin
work/gemma4_e2b_it/ple_int4_v1_group64_20261021/ple_int4.bin
```

大小：

```text
embedding_int4.bin  226492512 bytes
ple_int4.bin        1321205856 bytes
```

已有 INT4 资产目录：

```text
assets/assets_gemma4_w4a16_embint4_pleint4_group64_np8_20261022
```

其中旧 YAML 为：

```yaml
vocabSize: 262144
modelInputType: INT16
embeddingFileType: INT4
pleFileType: INT4
pleInputType: FP16
```

旧 `pleInputType: FP16` 不符合当前目标，需要重新渲染为 `INT16` 并重新上机验证。

## INT16 fallback 设备包和结果

设备稳定性 fallback：

```text
assets/assets_gemma-4-E2B-it_np8_ctx4096_20261022_int16_embedded
```

主要文件：

```text
embedding_int16.bin                          805306368 bytes
ple_int16.bin                                4697620480 bytes
ctx4096_256t4096c_0_opt_sharedkv_embedded.dla 300088615 bytes
ctx4096_1t4096c_0_embedded.dla               1177431645 bytes
tokenizer_gemma4.model                        4689016 bytes
gemma4_e2b_device_ctx4096.yaml                3817 bytes
```

YAML 的 Embedding/PLE 类型均为 INT16。这个包在手机端 5 条 prompt 的成功记录中完成
`rc=0`，但输出有乱码，只能证明执行链路，不能证明精度，也不能作为 INT4 结果。

## 手机端命令和日志

```bash
export DEVBASE=/data/local/tmp/llm_cmdtool_g4v2
bash scripts/device/run_gemma4_device.sh \
  --assets assets/assets_gemma-4-E2B-it_np8_ctx4096_20261022_int16_embedded \
  --yaml gemma4_e2b_device_ctx4096.yaml \
  --out verify_logs/device_final_int16_embedded_bench5_300ms_20261023_final \
  --prompts verify_logs/device_fp16_embedded_safe5_20261022/prompts \
  -m 30 --extra "--first-token-with-gen-model"
```

有效数据记录：

```text
verify_logs/device_final_int16_embedded_bench5_300ms_20261023_final/
verify_logs/device_final_int16_t2_300ms_20261023_retry/
verify_logs/device_final_int16_t3_300ms_20261023_retry/
verify_logs/device_final_int16_t4_300ms_20261023_r4/
```

旧 INT16 结果范围：prefill 约 845～1885 tok/s，decode 约 19～25 tok/s。

## CPU/RSS 双重采样

脚本：

```text
scripts/device/run_gemma4_device.sh
scripts/device/summarize_resource_metrics.py
```

采集：

```text
/proc/<pid>/status: VmRSS, VmHWM, VmPeak, RssAnon, RssFile, RssShmem
/proc/<pid>/smaps_rollup: Rss/Pss，每四次采集一次
/proc/<pid>/task/*/stat: 所有线程 CPU jiffies
```

名义间隔 300ms，优化后实际约 351～422ms，平均约 360～381ms。成功记录显示：

```text
RSS 峰值 615～895 MiB
PSS 峰值 652～919 MiB
VmHWM 约 1257 MiB
```

`VmPeak` 是虚拟地址空间峰值，不是物理内存；RSS/PSS 不包含 MDLA/DMA-BUF。

## 打包脚本修正

修改：`scripts/deploy/gemma4_v2/8_multictx_np8.sh`。

当前规则：

```text
LUT_TYPE=INT4（默认）
  选择 embedding_int4.bin / ple_int4.bin
  EMBEDDING_FILE_TYPE=INT4
  PLE_FILE_TYPE=INT4
  PLE_INPUT_TYPE=INT16

LUT_TYPE=INT16（显式 fallback）
  选择 embedding_int16.bin / ple_int16.bin
```

缺少目标 INT4 文件时直接失败，避免静默打包成 INT16。

验证：

```bash
bash -n scripts/deploy/gemma4_v2/8_multictx_np8.sh
bash -n scripts/deploy/gemma4_v2/6_package_assets.sh
git diff --check
```

## 尚未完成的验收项

1. 将 group64 INT4 文件放入本次 NP8 ctx4096 的目标固定目录并重新打包；
2. 生成 `embeddingFileType: INT4`、`pleFileType: INT4`、`pleInputType: INT16` YAML；
3. 重新 push INT4 包和兼容 DLA；
4. 手机端运行至少 5 条 prompt；
5. 记录 rc、prefill/decode、300ms CPU/RSS/PSS/VmHWM；
6. 处理或明确记录 INT4 非零 LUT 的 SIGSEGV/乱码问题。

INT16 fallback 的 benchmark 不能替代 INT4 最终验收。
+
## 2026-10-23 Embedding/PLE INT4 正式 PTQ 接入

入口修改：2_ptq.sh 新增 G4_PTQ_PRECISION_JSON，直接传入目标配置路径，避免固定 basename 覆盖旧实验目录；同时按对象校验 Embedding/PLE 的 lut_quant 合约。Embedding 为 INT4/INT8/group64/INT16，PLE 为 INT4/INT8/group64/FP32，格式均为 G4LUTI4。

正式命令：
export G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
export G4_PRECISION_JSON_SRC=$PWD/configs/gemma4/quant_w4a16_embint4_pleint4_group64_ptq.json
export G4_PTQ_PRECISION_JSON=$PWD/configs/gemma4/quant_w4a16_embint4_pleint4_group64_ptq.json
export G4_PTQ_NAME=gemma-4-E2B-it_quant_w4a16_embint4_pleint4_group64_ptq_Overall
source scripts/deploy/gemma4_v2/00_env.sh
bash scripts/deploy/gemma4_v2/2_ptq.sh

PTQ 结果：
输出目录：work/gemma4_e2b_it/quantized_models/dynamic_shape/gemma-4-E2B-it_quant_w4a16_embint4_pleint4_group64_ptq_Overall/llm
TFLite：36 个（layer 0~35）；pickle：36 个；Weight optimization：None；RAM peak：35.69 GB；Elapsed time：15:51。

PTQ q4 中间容器：
embedding_q4.i8 402,653,184 bytes；embedding_q4.i8.scales.f32 25,165,824 bytes；
ple_q4.i8 2,348,810,240 bytes；ple_q4.i8.scales.f32 146,800,640 bytes。
Embedding rows=262144、cols=1536、groups_per_row=24；PLE rows=262144、cols=8960、groups_per_row=140；两者 q4 范围均为 [-7,7]，scale 均有限且为正数。

PTQ 来源的 G4LUTI4：
Embedding：work/gemma4_e2b_it/g4luti4_ptq_group64_fp32ple/embedding.g4luti4，226,492,512 bytes，group_size=64，output_type=INT16，output_scale=0.0006681208033114672，q4_bit_exact=true。
PLE：work/gemma4_e2b_it/g4luti4_ptq_group64_fp32ple/ple.g4luti4，1,321,205,856 bytes，group_size=64，output_type=FP32，output_scale=1.0，q4_bit_exact=true。

导出命令：
`scripts/embedding_int4/export_q4_luts_from_ptq.py --ptq-dir <PTQ>/llm --embedding-info <PTQ>/*_info_0.json --embedding-scale-index 2 --ple-info <PTQ>/*_info_0.json --ple-output-type FP32 --ple-output-scale 1.0 --output-dir work/gemma4_e2b_it/g4luti4_ptq_group64_fp32ple`。

PLE 接口结论：
layer 0 的 PTQ info 显示 input_shapes[1]=[None,None,35,256]、input_dtypes[1]=float32、input_scales[1]=null。因此当前选择保持 PLE INT4 → FP32；导出器显式使用 output_scale=1.0，不读取空的 PLE input scale。PLE INT4 → INT16 仍是后续独立接口方案。

完成边界：
Embedding INT4 PTQ q4 容器：PASS
PLE INT4 PTQ q4 容器（metadata FP32）：PASS
Embedding PTQ 来源 G4LUTI4 INT16：PASS
PLE PTQ 来源 G4LUTI4 FP32：PASS
PLE 当前图输入：FLOAT32

尚未完成：fix-shape、surgery、MDLA 编译及设备端运行；设备 YAML 应保持 PLE 文件为 INT4、PLE 输入类型为 FP32，并以 MDLA 实际 IO 校验为准。

+
## Embedding/PLE 原始与 INT4 大小核对

核对来源：

```text
原始模型：/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it/model.safetensors
Embedding INT4：work/gemma4_e2b_it/embedding_int4_v1_group64_20261021/embedding_int4.bin
PLE INT4：work/gemma4_e2b_it/ple_int4_v1_group64_20261021/ple_int4.bin
```

原始 `model.safetensors` 中两个张量均为 BF16：

| 部分 | Shape | 原始 BF16 | INT4 group64 | 压缩比 |
|---|---:|---:|---:|---:|
| Embedding | `[262144,1536]` | 805,306,368 bytes / 768 MiB | 226,492,512 bytes / 216 MiB | 3.556x |
| PLE | `[262144,8960]` | 4,697,620,480 bytes / 4480 MiB | 1,321,205,856 bytes / 1260 MiB | 3.556x |
| 合计 | — | 5,502,926,848 bytes / 5248 MiB | 1,547,698,368 bytes / 1476 MiB | 3.556x |

理论大小公式：

```text
INT4 payload = element_count × 0.5 byte
FP32 scales = ceil(element_count / group_size) × 4 bytes
G4LUTI4 file = INT4 payload + FP32 scales + 96-byte header
```

逐项核算：

```text
Embedding:
  elements = 262144 × 1536 = 402653184
  groups   = 402653184 / 64 = 6291456
  theory   = 201326592 + 25165824 + 96 = 226492512 bytes
  actual   = 226492512 bytes

PLE:
  elements = 262144 × 8960 = 2348810240
  groups   = 2348810240 / 64 = 36700160
  theory   = 1174405120 + 146800640 + 96 = 1321205856 bytes
  actual   = 1321205856 bytes
```

结论：现有两个 INT4 文件的实际大小与 group64、每组一个 FP32 scale、96-byte
G4LUTI4 header 的理论值完全一致，物理存储确实是 INT4 packed。group size 不重复
写入每个 group，而是由格式元数据/约定解释。

注意：当前 PLE 的 `output_type=FP32` 与 PTQ 图 `input_dtypes[1]=float32` 一致；
G4LUTI4 的 `output_scale=1.0` 为显式 FP32 接口约定。PLE `INT4 -> INT16` 仍需另行
设计和真实 runtime 验证，不能与本次 FP32 路径混用。

## 2026-10-23 Mixed PTQ 后续部署链路

- `3_fix_shape.sh` 已修正为使用 `G4_PTQ_NAME/G4_SHAPE_*`，完成 `256t4096c` 和 `1t4096c` 两张合并图；RAM peak 16.50 GB，耗时 6:32。
- `3b_cut_tflite.sh` 完成 4 张 cut 图：两个 shape 各有 `*_opt_sharedkv.tflite` 和 `*_tail_sharedkv.tflite`。
- `3c_rename_quantized.sh` 将结果保存到 `work/gemma4_e2b_it/quantized_models_fixed/<PTQ_NAME>`。
- NP8/MT6899 MDLA 编译：PROM DLA 299,831,507 bytes，GEN DLA 1,177,519,045 bytes。GEN 首次失败原因是 NP8 不接受 converter 10.x 的 `FULLY_CONNECTED v13`；`5_build_mdla.sh` 已改为对 PROM/GEN 都执行 v13→v11 兼容修正后重编成功。
- extract-shared 成功：PROM shared DLA 2,765,829 bytes，GEN shared DLA 880,121,415 bytes，SHA 295,789,568 bytes。
- assets：`assets/assets_gemma-4-E2B-it_np8_ctx4096_embint4_pleint4_fp32_20261023_060734`，约 2.6G；YAML 使用 `embeddingFileType=INT4`、`pleFileType=INT4`、`pleInputType=FP32`，Embedding/PLE 均指向 G4LUTI4。
- MT6897 暂停：当前环境未找到其额外要求的 `llm.ncl`；本次实际编译使用与设备 runtime 匹配的 NP8/MT6899。

## PLE FP32 buffer 诊断

设备日志中的 `4587520` bytes 不是按 128 token 配置出来的。固定图的 PLE 输入为 `[1,256,35,256]`，每 token 的 PLE row 为 `35*256=8960` 个元素；`256*8960*2=4587520`，说明 DLA/MDLA 物理输入按 FP16（2 bytes）分配。当前 YAML 设置 `pleInputType: FP32` 后，runtime 按 4 bytes 写入，要求 `256*8960*4=9175040` bytes，于是错误日志将 `4587520/(8960*4)=128` 暗示成“128 token”。

代码依据：`llm_runtime.cpp` 将 PLE LUT输出直接绑定到 DLA PLE input buffer；`token_embedding.cpp` 用 `kOutputTypeSize` 检查写入大小。当前 runtime 还要求 G4LUTI4 header output_type 与 `pleInputType` 一致，因此不能简单把 YAML 改成 FP16 而继续使用 header=`FP32` 的 PLE 文件。正确方案需要物理 FP16 接口与逻辑 FP32 解码语义分离，或将 PLE G4LUTI4 header/运行时输出统一改为 FP16 后重新验证。

### 配置字段语义调整

为避免把 PLE 的设备输出类型误解为 PTQ scale 类型，`lut_quant` 配置拆分为：

- `runtime_output_type`：LUT 解码后写入设备 buffer 的类型；Embedding 为 `INT16`，PLE 为 `FP16`。
- `ptq_scale_type`：group scale 的存储/计算类型，固定为 `FP32`。

新的 PLE 语义为 `INT4 × FP32 scale -> FP32 中间计算 -> FP16 runtime buffer`。旧的
`output_type` 仅作为兼容别名读取，新的配置使用上述两个明确字段。
### 方向1设备验证结果

新 assets 采用 PLE `INT4 -> FP16` runtime buffer、FP32 group scale。设备日志确认
`tokens=256 required=4587520`，原来的 128 token 推导和 buffer insufficient 错误已消失。
PTQ/fix-shape 图的 `input_embeds_0` 实际为 INT16，scale 为
`0.0006681208033114672`、zero point 为 0；因此 t1/t5 的 DLA SIGSEGV 不能归因于
Embedding INT16 与 FP16 接口不匹配，需继续检查 DLA 执行和 PROM/GEN 交接。

## 2026-10-23 阶段状态（已被后续记录更新）

当前最终目标配置为：Embedding INT4 group64 → INT16，PLE INT4 group64 → FP16；两者
均由 PTQ 阶段的 INT8 兼容容器承载，G4LUTI4 导出后为 packed INT4 + FP32 group scale。
PLE 的真实执行链路是：

```text
INT4 LUT × FP32 scale → FP32 中间计算 → FP16 runtime buffer → FP16 MDLA input
```

PTQ/fix-shape 图的 `input_embeds_0` 是 INT16，PLE 逻辑 tensor
`per_layer_emb_0` 是 FLOAT32；后者是图逻辑接口，不要求设备 runtime 分配 FP32 buffer。
当前设备 YAML 已使用 `modelInputType: INT16` 和 `pleInputType: FP16`。

最新资产目录：
`assets/assets_gemma-4-E2B-it_np8_ctx4096_embint4_pleint4_fp16_20261023_074255/`。

该资产已完整推送手机。t1、t5 两条 prompt 均在 DLA 执行阶段 SIGSEGV（rc=139），但
日志确认 Embedding/PLE 均按 256 token 正确分配和 lookup：Embedding 786432 bytes，
PLE 4587520 bytes；没有 `buffer insufficient`。因此“128 token”问题已经解决，剩余
故障应从 PROM/GEN 交接、shared DLA/设备库兼容性及首次 token 路径继续定位。

项目侧的完整命令、路径、文件大小、类型逻辑和下一步计划见：
[Gemma4 local RoPE SIGSEGV investigation](../mediatek-npu/gemma4-local-rope-sigsegv-investigation-20261023.md).

## 2026-10-25：Embedding/PLE INT4 → INT16 PTQ 修正

本轮目标改为 Embedding 和 PLE 均为逻辑 INT4、group64，PTQ 阶段以 INT8 容器承载，
运行时 G4LUTI4 解码后均写入 INT16；PTQ 不使用 Hessian。关键配置必须同时满足：

```json
{
  "default": "sym4W_sym16A",
  "embeddings": "int8",
  "ple": "sym4W_sym16A",
  "lut_quant": {
    "embedding": {"logical_precision": "int4", "storage_precision": "int8", "group_size": 64, "runtime_output_type": "int16", "ptq_scale_type": "fp32", "format": "G4LUTI4"},
    "ple": {"logical_precision": "int4", "storage_precision": "int8", "group_size": 64, "runtime_output_type": "int16", "ptq_scale_type": "fp32", "format": "G4LUTI4"}
  }
}
```

`default` 只提供未单独指定模块的回退值；显式的 `ple` 会覆盖它。因此仅把
`default` 设为 `sym4W_sym16A`、而保留 `ple: int8`，不能得到 PLE INT16 图输入。
SDK 的 `PTQPrecisionConfig._parse_lut_quant_config()` 原先还把 PLE runtime 输出硬编码为
`fp16`，已通过可移植 patch `patches/mtk_llm_sdk/ple_int16_runtime_output.patch` 改为只接受
INT16。目标环境中的 PTQ 已确认通过该校验并开始加载模型，日志为
`work/gemma4_e2b_it/logs/ptq_embint4_pleint16_nohessian_20261025.log`。
但第 0 层产物同时证明：`ple_q4.i8.json` 的 LUT 输出类型已是 INT16，TFLite
`input_dtypes[1]` 仍是 FLOAT32、`input_scales[1]` 为 null。故 LUT 输出类型与 TFLite
外部 PLE 接口仍未接通，不能据此进入设备验证；下一步必须修改 Gecko4 trace/converter
接口，使 PLE 外部输入真正成为 INT16，再重新完整 PTQ。
### 2026-10-25 PTQ 输出目录衔接

本次 PTQ 使用显式输出目录：
`work/gemma4_e2b_it/quantized_models_w4a16_embint4_pleint16_nohessian_int16graph_20261025/`。
`scripts/deploy/gemma4_v2/3_fix_shape.sh` 已支持通过 `G4_PTQ_OUTPUT_DIR` 直接消费该目录，
不再依赖旧的 `quantized_models/dynamic_shape/$G4_PTQ_NAME` 硬编码路径。PTQ 仍在执行中，
尚未产生本次目标版本的设备 benchmark。
### 2026-10-25：INT4/INT16 目标版本端到端验证

设备结果、质量判定和资源数据见
[2026-10-25 端侧验证报告](gemma4-device-validation-results-20261025.md)。本时间线不再重复同一组 prompt 和结论。
