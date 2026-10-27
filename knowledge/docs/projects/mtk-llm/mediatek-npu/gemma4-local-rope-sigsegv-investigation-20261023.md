# Gemma4 Local RoPE SIGSEGV 调查与修复（2026-10-23）

This record follows the intermittent device SIGSEGV from initial symptoms to
the confirmed local RoPE LUT buffer-size bug and its device regression.

## 当前结论

- 环境、无 Hessian PTQ、fix-shape、surgery、PROM cut、NP8/MT6897 目标链路中的 NP8
  MDLA 编译、G4LUTI4 导出、assets 打包和手机推送已完成。
- Embedding/PLE 文件均已核实为物理 packed INT4，group64，每组 FP32 scale。
- Embedding 运行时为 `INT4 → INT16`；PLE 运行时为
  `INT4 × FP32 scale → FP32 中间计算 → FP16 buffer → FP16 MDLA input`。
- TFLite/PTQ 的 PLE 逻辑输入仍可为 FLOAT32；这不等于设备 buffer 必须为 FP32。
- 新 FP16 PLE runtime 资产已推送，但 t1/t5 在 DLA 执行阶段 SIGSEGV，设备验收未通过。
- 设备日志已确认 256 token 的 Embedding/PLE buffer 和 lookup 均成功，“128 token”问题
  已解决；剩余问题应定位 PROM/GEN 交接、shared DLA/设备库兼容性或首次 token 路径。

## 关键产物

```text
模型：/data/xin.xu5/projs/gemma_proj/models/gemma-4-E2B-it
环境：/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
资产：assets/assets_gemma-4-E2B-it_np8_ctx4096_embint4_pleint4_fp16_20261023_074255/
Embedding：226,492,512 bytes
PLE：1,321,205,856 bytes
```

完整命令、YAML、PTQ 配置、类型推导、日志路径和下一步计划以项目文档为准。

## SIGSEGV 当前定位

t1/t5 均在两组 LUT lookup 完成后崩溃；`fault_pc` 落在 Android `libc.so`，上一层
落在设备 `libmtk_llm.so`，当前更像首次 DLA 调用前后由 runtime/backend 发起的 memcpy
访问错误地址或错误长度，而不是 G4LUTI4 lookup 本身。下一步应固定同一 main/YAML，
比较 INT16、已有 INT4、当前 INT4+FP16 PLE 三组控制资产；同时在
`registerRuntimeIO`、`runInferencePrologue`、PROM run、GEN run 前后记录 buffer 地址、
size、IO index 和 graph 名称，并采集 logcat/APU/MDLA kernel 日志后符号化
`libmtk_llm.so` 地址。

当前已排除“128 token buffer”问题；仍需排除 PLE FP16 stride/alias、PROM-GEN 交接、
shared weights/SHA、NP8 runtime 兼容性和首次 token hot-swap 路径。

同一诊断二进制加入 `stderr+fflush` marker 后，成功样本完整通过 30 组 cache memcpy；
失败样本的 caller 仍符号归属 `appendInOutCaches()`，但没有出现第一条 marker。当前应
保存同一二进制下的完整逐帧栈和 executor/chunk 标识，先确认失败栈与成功栈是否属于
同一执行路径，再继续解释 fault address。

### addr2line 结果

对 `libmtk_llm.so` 按 ELF load bias 修正 ASLR 地址后，t1/t5 的 caller 都解析为同一
个 ELF 地址 `0x1570b0`：

```text
mtk::llm_helper::RingBufferCacheManager::appendInOutCaches(...)
llm_helper/ringbuffer_cache_manager.cpp:314
```

对应 memcpy 位于该函数 326～328 行，当前最高优先级应检查 ring-buffer cache 的源/目标
地址、stride、padding 和 copy size，而不是继续从 LUT lookup 或“128 token”方向排查。

诊断版加入 cache 边界和 hot-swap 阶段日志后，t1 成功、t5 先后出现一次 `rc=139`、
一次 `signal=6/rc=134`，随后再次成功并输出 `series wickets`（约 15.15 tok/s）。成功
样本完整通过 `selectRuntime`、cache shape、`defineIOs`、`updateModelIO`、
`registerRuntimeIO`；失败样本的报告回溯落在 `appendInOutCaches()`，但没有出现该版本
新增的第一条 `RBC_BEFORE_ENSURE_INIT`。因此不能把失败直接归因为已观测的 memcpy 或
hot-swap/APU 状态；必须先用同一二进制的 TID、chunk/model 标识把 fault 线程与实际
执行路径关联起来。

当前版本再次复现 t5 的 SIGSEGV：libc memcpy 的 `fault_pc` 为 `0x749fb3ca80`，其
caller 通过当前 `libmtk_llm.so` 映射换算为 ELF `0x158520`，落在
`RingBufferCacheManager::appendInOutCaches()` 的 memcpy（源码 368～369 行）。
`fault_addr=0x74cba2f600` 位于进程内 `libsentencepiece.so` 的 `r--p` 映射范围内；
下一步应直接打印 memcpy 的 source/destination/length，并核对 fault_addr 与两者的关系。

### TID/chunk 关联验证（2026-10-23）

诊断版继续增加了 crash handler 的 `pid/tid`、ring-buffer marker 的 TID，以及每个
`runInferenceEpilogue()` 的 model/runtime 和前后边界日志。重新编译并推送后，同一资产、
同一 t5 prompt 连续 5 次均成功，日志目录为：

```text
verify_logs/device_gemma4_sigsegv_tid_20261023_084016/
verify_logs/device_gemma4_sigsegv_tid_20261023_084051_r2/
verify_logs/device_gemma4_sigsegv_tid_20261023_084112_r3/
verify_logs/device_gemma4_sigsegv_tid_20261023_084133_r4/
verify_logs/device_gemma4_sigsegv_tid_20261023_084154_r5/
```

每次均能看到同一 TID 从 `RBC_BEFORE_MEMCPY` 到 `RBC_AFTER_MEMCPY`，并到达
`RBC_EPILOGUE_AFTER`；最后一次 TID 为 `29933`，cache 27/28/29 均成对完成。这证明
当前版本实际执行的 ring-buffer memcpy 路径和边界检查在这些样本中通过，仍未证明历史
SIGSEGV 的 fault 线程就是该路径。在再次取得带 TID 的失败样本前，根因状态保持为
“失败路径未关联”，不作 runtime/APU 时序归因。

### 带寄存器的 SIGSEGV 精确定位（2026-10-23）

在 crash handler 增加 AArch64 `x0~x3/sp/x29/x30` 后，取得失败样本：

```text
verify_logs/device_gemma4_sigsegv_regs_20261023_084809_r12/device_logs/t5.log
CRASH signal=11 pid=30689 tid=30689 fault_addr=0x7f45da8600
fault_pc=0x7f25d33a80
CRASH_REGS x0=0x7f45da8600 x1=0xb400007c5a0e1400 x2=0x200
```

按 AArch64 `memcpy(dst, src, len)` 调用约定：

- `dst=x0=0x7f45da8600`，位于设备进程中 `android.hardware.cas@1.0.so` 的只读映射；
- `src=x1` 去除 MTE tag 后为 `0x7c5a0e1400`，位于有效匿名可读写映射；
- `len=x2=0x200`，即 512 bytes；
- `fault_pc` 位于 Android libc memcpy；回溯 caller 按该次映射换算为
  `libmtk_llm.so` ELF `0x158ef4`，即 `ringbuffer_cache_manager.cpp:414` 的
  cache-copy 循环。

因此本次 fault 的直接事实是：libc fault 发生在 ring-buffer 相关调用栈中，但返回地址
落在诊断 `fprintf` 参数附近，不能把该次 `x0~x2` 直接当作真实 `std::memcpy` 的参数。
最新失败样本的 caller 进一步换算为 `libmtk_llm.so` ELF `0x159058`，对应
`ringbuffer_cache_manager.cpp:446` 的 `resetRingBuffer()` 循环附近；另一失败样本落在
`RBC_BEFORE_MEMCPY` 的格式化参数行。真实 memcpy 是否已执行仍需固定 marker 判断。

```cpp
std::memcpy(cacheRingBuffer, cacheRingBuffer + ringOffsetBytes, inputCacheSizeBytes);
```

初始化阶段 `RBC_SET_BUFFER` 打印的 30 个 input 指针均在正常缓存区；当前仍需区分
“诊断 fprintf 触发 fault”与“真实 reset/append memcpy 触发 fault”。已增加不格式化指针的
`RBC_COPY_BEFORE_FORMAT` 和 `RBC_RESET_BEFORE_FORMAT` 原始 `write()` marker，下一轮
复现后再确认真实 memcpy 的 index、dst、src、offset 和长度。该结论不对 runtime/APU
时序作归因。
已在 `resetRingBuffer()` memcpy 前增加 `RBC_RESET_BEGIN/RBC_RESET_BUFFER`（含 TID、index、
dst/src、offset 和 bytes），并通过 `git diff --check` 与 Android cmdtool 编译；该版本
尚未再次推送设备，下一轮复现需先执行 `bash scripts/device/push_cmdtool_gemma4_v2.sh --tool`。
### epilogue 阶段 marker 验证（2026-10-23）

最新阶段 marker 诊断版已推送并运行：

```text
verify_logs/device_gemma4_sigsegv_stage_20261023_094055/device_logs/t5.log
```

本次 t5 成功，256t 和 1t 均依次通过 `BEFORE_EVICTION`、`AFTER_EVICTION`、
`AFTER_ADVANCE`、`BEFORE_APPEND`、30 次 `RBC_COPY_BEFORE_FORMAT` 和
`AFTER_APPEND`，未触发 SIGSEGV 或 reset marker。该结果确认阶段划分有效；历史失败
仍需在失败样本中观察最后一个固定 marker，不能仅凭成功样本宣布修复。

### SIGSEGV 根因修复与回归（2026-10-23）

通过 prologue、Neuron enqueue、mask、RoPE 分段 marker 将故障定位到 local RoPE LUT 的
第二组（local）sin 写入。失败样本中 local sin buffer 实际映射为 64 KiB，例如：

```text
RBC_LOCAL_ROT_PTR index=1 ptr=0x79b28f7000
mapping: 0x79b28f7000-0x79b2907000 rw-s
fault_addr=0x79b2916600
```

runtime 原来用 global `headDim=512` 创建 local LUT；`localHeadDim: 256` 虽已写在
Gemma4 YAML 中，但 parser 未读取，且 local LUT 构造仍使用 `modelOptions.headDim`。
在 `useRotEmbHalfDim=true`、left padding=251、prompt batch=256 时，local LUT 每个
cos/sin buffer 按 128 KiB 写入，越过 64 KiB buffer；cos 后方偶尔仍是可写 DMA 映射，
sin 后方是不可写区域，于是表现为间歇性 SIGSEGV。

修复内容：

- `mtk_llm_options.h` 增加 `localRotEmbHeadDim`；
- `config_parser.cpp` 读取既有 YAML 字段 `localHeadDim`；
- `llm_runtime.cpp` 创建 local LUT 时使用 `localRotEmbHeadDim`，缺省才回退到
  `headDim`；当前模型实际使用 256，global LUT 仍使用 512；
- 保留固定 marker 和 crash 寄存器信息，便于回归验证。

编译与推送：

```bash
NDK=/workspace/xin.xu5/utilssets/tools/android/sdk/ndk/29.0.14206865 \
  bash scripts/deploy/gemma4_v2/7_build_cmdtool.sh
bash scripts/device/push_cmdtool_gemma4_v2.sh --tool
```

修复后连续 5 次 t5 验证全部通过：

```text
verify_logs/device_gemma4_sigsegv_fixed_20261023_100407_r1/
verify_logs/device_gemma4_sigsegv_fixed_20261023_100431_r2/
verify_logs/device_gemma4_sigsegv_fixed_20261023_100452_r3/
verify_logs/device_gemma4_sigsegv_fixed_20261023_100513_r4/
verify_logs/device_gemma4_sigsegv_fixed_20261023_100535_r5/
```

每次均为 `CRASH=0`，完成 3 次 local RoPE 写入并到达 `RBC_EPILOGUE_AFTER`，覆盖
256-token prompt runtime 和 1-token decode runtime。当前 SIGSEGV 已修复并通过设备回归。
