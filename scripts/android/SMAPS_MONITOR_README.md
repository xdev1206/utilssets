# smaps_monitor.py - Android 进程内存/CPU 监控与分析工具

## 概述

`smaps_monitor.py` 是一个运行在 PC 端的 Android 进程监控工具，通过 adb 与设备通信，提供：

1. **持续监控**：实时采集进程的 VmRSS、VmHWM、CPU% 趋势
2. **smaps 分析**：按 35 种 heap 类型分类统计内存分布（.so、.jar、Dalvik、Native 等）
3. **灵活模式**：支持持续监控、单次快照、定时快照等多种使用方式

## 监控指标

### 基础指标（持续监控模式）

| 指标 | 说明 | 数据来源 |
|------|------|----------|
| **VmRSS** | 进程当前物理内存占用（kB） | `/proc/<pid>/status` |
| **VmHWM** | 进程历史峰值物理内存（kB） | `/proc/<pid>/status` |
| **CPU%** | 进程 CPU 占用百分比 | `ps -p <pid> -o %CPU` |

### smaps 分析指标（35 种 heap 类型）

脚本按照 Android `dumpsys meminfo` 的分类标准，将 `/proc/<pid>/smaps` 中的内存映射分为 35 类：

| 类型 | 说明 | 示例 |
|------|------|------|
| **Native** | 原生堆内存 | `[heap]`, `[anon:libc_malloc]`, `[anon:scudo:*]` |
| **Stack** | 线程栈 | `[stack]`, `[anon:stack_and_tls:*]` |
| **Dalvik** | ART 虚拟机堆 | `[anon:dalvik-alloc space]`, `[anon:dalvik-main space]` |
| **Dalvik Other** | Dalvik 其他内存 | `[anon:dalvik-indirect ref]`, `[anon:dalvik-CompilerMetadata]` |
| **.so mmap** | 共享库映射 | `/system/lib64/libc.so` |
| **.jar mmap** | JAR 文件映射 | `/system/framework/framework.jar` |
| **.apk mmap** | APK 文件映射 | `/data/app/xxx/base.apk` |
| **.dex mmap** | DEX 文件映射 | `*.odex`, `*.vdex`, `*.dex` |
| **.oat mmap** | OAT 文件映射 | `*.oat` |
| **.art mmap** | ART 文件映射 | `*.art` |
| **Gfx dev** | 图形设备内存 | `/dev/kgsl-3d0` |
| **Ashmem** | Android 共享内存 | `/dev/ashmem/*` |
| **Cursor** | CursorWindow | `/dev/ashmem/CursorWindow` |
| **Unknown** | 未分类匿名映射 | `[anon:*]` |
| **Other mmap** | 其他文件映射 | 未匹配的文件路径 |

每种类型统计：
- **Total**：PSS + SwapPss 总和
- **PSS**：Proportional Set Size（按比例共享的物理内存）
- **SwapPss**：交换到 swap 的内存

## 使用方法

### 基本语法

```bash
python3 smaps_monitor.py [选项]
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-p, --pid PID` | 目标进程 PID | 无（与 `-n` 二选一） |
| `-n, --name NAME` | 目标进程名称（通过 `pidof` 解析） | 无 |
| `--wait` | 等待进程启动（与 `-n` 配合使用） | false |
| `--interval SEC` | 采集间隔（秒） | 0.3 |
| `--duration SEC` | 最大监控时长（秒） | 无限制 |
| `--once` | 单次 smaps 分析，不进入监控循环 | false |
| `--smaps-interval SEC` | smaps 快照采集间隔（秒） | 仅启动时采集一次 |
| `--no-smaps` | 跳过 smaps 采集 | false |
| `-o, --output {txt,xls}` | smaps 分析输出格式 | txt |
| `-d, --dir DIR` | 输出目录 | 自动生成 |
| `-s, --simple` | 简化输出（不显示每个 mapping 的明细） | false |

### 使用示例

#### 1. 监控指定 PID

```bash
python3 smaps_monitor.py -p 1234
```

#### 2. 按进程名监控（等待启动）

```bash
python3 smaps_monitor.py -n com.example.app --wait
```

#### 3. 单次 smaps 分析

```bash
python3 smaps_monitor.py -p 1234 --once
```

#### 4. 定时采集 smaps 快照

```bash
python3 smaps_monitor.py -p 1234 --smaps-interval 5
```

每 5 秒采集一次 smaps，生成多个快照文件。

#### 5. 输出 Excel 格式

```bash
python3 smaps_monitor.py -p 1234 -o xls
```

需要安装 `xlsxwriter`：`pip install xlsxwriter`

#### 6. 仅监控趋势，不采集 smaps

```bash
python3 smaps_monitor.py -p 1234 --no-smaps
```

#### 7. 限制监控时长

```bash
python3 smaps_monitor.py -p 1234 --duration 60
```

监控 60 秒后自动停止。

## 输出文件

脚本会在输出目录生成以下文件：

```
smaps_monitor_pid1234_20260717_162725/
├── trend.csv              # 趋势数据（时间戳、VmRSS、VmHWM、CPU%）
├── summary.txt            # 监控摘要（峰值、最后值）
├── smaps_raw_0.txt        # 原始 smaps 数据（第 0 次快照）
├── smaps_analysis_0.txt   # smaps 分类分析（第 0 次快照）
├── smaps_raw_1.txt        # 原始 smaps 数据（第 1 次快照）
└── smaps_analysis_1.txt   # smaps 分类分析（第 1 次快照）
```

### trend.csv 格式

```csv
timestamp_ms,vmrss_kb,vmhwm_kb,cpu_percent
1784278839076,426872,550600,82.0
1784278839718,433868,550600,74.2
1784278840373,433868,550600,71.3
```

### summary.txt 格式

```
PID: 1234
Samples: 11
Peak VmRSS: 437 kB (0.43 MB)
Peak VmHWM: 550 kB (0.54 MB)
Last VmRSS: 390 kB (0.38 MB)
Peak CPU: 97.9%

PEAK_VMHWM_KB=550
LAST_VMRSS_KB=390
PEAK_CPU_PERCENT=97
```

末尾的 `PEAK_*` 和 `LAST_*` 标记便于脚本解析（如 `run.sh` 使用 `grep` 提取）。

### smaps_analysis.txt 格式

```
Unknown : 0.000 M
    pss: 0.000 M
    swapPss: 0.000 M
Dalvik : 120.500 M
    pss: 120.500 M
    swapPss: 0.000 M
        [anon:dalvik-alloc space] : 80000 kB
        [anon:dalvik-main space] : 40000 kB
Native : 45.200 M
    pss: 45.200 M
    swapPss: 0.000 M
        [anon:libc_malloc] : 30000 kB
        /system/lib64/libc.so : 15000 kB
...
```

## 与 run.sh 集成

`run.sh` 使用 `smaps_monitor.py` 监控 `llm_demo` 进程：

```bash
# 启动 llm_demo 后台运行
adb shell "(./llm_demo ... & echo \$! > pidfile) &"

# 获取 PID
PID=$(adb shell "cat pidfile")

# 启动监控（后台）
python3 smaps_monitor.py -p $PID --interval 0.5 --no-smaps -d "$MONITOR_DIR" &

# 等待 llm_demo 退出
adb shell "while kill -0 $PID; do sleep 0.5; done"

# 等待监控退出
wait $MONITOR_JOB_PID

# 从 summary.txt 提取峰值
PEAK_VMHWM=$(grep 'PEAK_VMHWM_KB=' "$MONITOR_SUMMARY" | cut -d= -f2)
```

## 性能说明

- **采集间隔**：默认 300ms，实际间隔约 640-660ms（命令执行约 340ms + sleep 300ms）
- **adb 开销**：每次采集执行 1 个合并命令（`cat /proc/pid/status | grep ...; ps ...`）
- **smaps 采集**：单独执行 `cat /proc/pid/smaps`，耗时约 500ms-1s
- **进程检测**：通过 `cat /proc/<pid>/status` 判断进程是否存在

## 依赖

- Python 3.6+
- adb（Android Debug Bridge）
- pandas + xlsxwriter（可选，用于 Excel 输出）

```bash
pip install pandas xlsxwriter
```

## 常见问题

### Q: 为什么实际采集间隔比设置的长？

A: 每次采集需要执行 adb shell 命令，网络延迟和命令执行时间约 300-400ms。如果需要更短的间隔，建议在设备端运行采集脚本。

### Q: CPU% 为 0 或不准确？

A: `ps` 命令的 CPU% 是进程生命周期内的平均值，不是瞬时值。对于短时间运行的进程，可能不准确。

### Q: 如何分析内存泄漏？

A: 使用 `--smaps-interval` 定时采集 smaps 快照，对比不同时间点的 `smaps_analysis.txt`，观察哪些 heap 类型持续增长。

### Q: 如何监控多个进程？

A: 当前版本只支持单进程监控。可以启动多个 `smaps_monitor.py` 实例，分别监控不同 PID。

## 版本历史

- **2026-07-17**: 重构为统一监控+分析工具
  - 合并 `cpu_mem_info.sh` 和 `smaps_parser.py` 功能
  - 添加 smaps 分类分析（35 种 heap 类型）
  - 支持持续监控、单次快照、定时快照
  - 优化采集性能（合并 adb 命令）
  - 修复进程检测问题（改用 `/proc/<pid>/status`）

