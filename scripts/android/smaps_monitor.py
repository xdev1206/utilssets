#!/usr/bin/env python
# -*- coding:utf-8 -*-

"""
Unified Android process memory/CPU monitor + smaps analyzer.

Runs on PC, communicates with device via adb.
Combines:
  - Continuous monitoring (VmRSS/VmHWM/CPU trend)
  - smaps heap classification (35 types)
"""

import argparse
import datetime
import os
import re
import subprocess
import sys
import time
from collections import Counter

try:
    import pandas as pd
    from pandas import DataFrame
    import xlsxwriter
    HAS_XLSX = True
except ImportError:
    HAS_XLSX = False

# ── Heap type constants (mirrors Android dumpsys meminfo classification) ──

HEAP_UNKNOWN = 0
HEAP_DALVIK = 1
HEAP_NATIVE = 2
HEAP_DALVIK_OTHER = 3
HEAP_STACK = 4
HEAP_CURSOR = 5
HEAP_ASHMEM = 6
HEAP_GL_DEV = 7
HEAP_UNKNOWN_DEV = 8
HEAP_SO = 9
HEAP_JAR = 10
HEAP_APK = 11
HEAP_TTF = 12
HEAP_DEX = 13
HEAP_OAT = 14
HEAP_ART = 15
HEAP_UNKNOWN_MAP = 16
HEAP_GRAPHICS = 17
HEAP_GL = 18
HEAP_OTHER_MEMTRACK = 19
HEAP_DALVIK_NORMAL = 20
HEAP_DALVIK_LARGE = 21
HEAP_DALVIK_ZYGOTE = 22
HEAP_DALVIK_NON_MOVING = 23
HEAP_DALVIK_OTHER_LINEARALLOC = 24
HEAP_DALVIK_OTHER_ACCOUNTING = 25
HEAP_DALVIK_OTHER_ZYGOTE_CODE_CACHE = 26
HEAP_DALVIK_OTHER_APP_CODE_CACHE = 27
HEAP_DALVIK_OTHER_COMPILER_METADATA = 28
HEAP_DALVIK_OTHER_INDIRECT_REFERENCE_TABLE = 29
HEAP_DEX_BOOT_VDEX = 30
HEAP_DEX_APP_DEX = 31
HEAP_DEX_APP_VDEX = 32
HEAP_ART_APP = 33
HEAP_ART_BOOT = 34

_NUM_HEAP = 35

PSS_TYPE = [
    "Unknown", "Dalvik", "Native", "Dalvik Other", "Stack", "Cursor",
    "Ashmem", "Gfx dev", "Other dev", ".so mmap", ".jar mmap", ".apk mmap",
    ".ttf mmap", ".dex mmap", ".oat mmap", ".art mmap", "Other mmap",
    "graphics", "gl", "other memtrack",
    "dalvik normal", "dalvik large", "dalvik zygote", "dalvik non moving",
    "dalvik other lineralloc", "dalvik other accounting",
    "dalvik other zygote code cache", "dalvik other app code cache",
    "dalvik other compiler metadata", "dalvik other indirect reference table",
    "dex boot vdex", "dex app dex", "dex app vdex",
    "heap art app", "heap art boot",
]

_HEAD_RE = re.compile(r'(\w*)-(\w*) (\S*) (\w*) (\w*):(\w*) (\w*)\s*(.+)$', re.I)
_PSS_RE = re.compile(r'Pss:\s+([0-9]*) kB', re.I)
_SWAP_PSS_RE = re.compile(r'SwapPss:\s+([0-9]*) kB', re.I)


def _is_boot_path(name):
    return "@boot" in name or "/boot" in name or "/apex" in name


def _classify_mapping(name):
    if name.endswith(" (deleted)"):
        name = name[:-len(" (deleted)")]

    if name.startswith("[heap]") or name.startswith("[anon:libc_malloc]") \
       or name.startswith("[anon:scudo:") or name.startswith("[anon:GWP-ASan"):
        return HEAP_NATIVE
    if name.startswith("[stack") or name.startswith("[anon:stack_and_tls:"):
        return HEAP_STACK
    if name.endswith(".so"):
        return HEAP_SO
    if name.endswith(".jar"):
        return HEAP_JAR
    if name.endswith(".apk"):
        return HEAP_APK
    if name.endswith(".ttf"):
        return HEAP_TTF
    if name.endswith(".odex") or (len(name) > 4 and ".dex" in name):
        return HEAP_DEX
    if name.endswith(".vdex"):
        return HEAP_DEX
    if name.endswith(".oat"):
        return HEAP_OAT
    if name.endswith(".art") or name.endswith(".art]"):
        return HEAP_ART
    if name.startswith("/dev"):
        if name.startswith("/dev/kgsl-3d0"):
            return HEAP_GL_DEV
        if "/dev/ashmem/CursorWindow" in name:
            return HEAP_CURSOR
        if name.startswith("/dev/ashmem/jit-zygote-cache"):
            return HEAP_DALVIK_OTHER
        if "/dev/ashmem" in name:
            return HEAP_ASHMEM
        return HEAP_UNKNOWN_DEV
    if name.startswith("/memfd:jit-cache"):
        return HEAP_DALVIK_OTHER
    if name.startswith("/memfd:jit-zygote-cache"):
        return HEAP_DALVIK_OTHER
    if name.startswith("[anon:"):
        if name.startswith("[anon:dalvik-"):
            if name.startswith("[anon:dalvik-LinearAlloc"):
                return HEAP_DALVIK_OTHER_LINEARALLOC
            if name.startswith("[anon:dalvik-alloc space") or name.startswith("[anon:dalvik-main space"):
                return HEAP_DALVIK
            if name.startswith("[anon:dalvik-large object space") or name.startswith("[anon:dalvik-free list large object space"):
                return HEAP_DALVIK
            if name.startswith("[anon:dalvik-non moving space"):
                return HEAP_DALVIK
            if name.startswith("[anon:dalvik-zygote space"):
                return HEAP_DALVIK
            if name.startswith("[anon:dalvik-indirect ref"):
                return HEAP_DALVIK_OTHER_INDIRECT_REFERENCE_TABLE
            if name.startswith("[anon:dalvik-jit-code-cache") or name.startswith("[anon:dalvik-data-code-cache"):
                return HEAP_DALVIK_OTHER_APP_CODE_CACHE
            if name.startswith("[anon:dalvik-CompilerMetadata"):
                return HEAP_DALVIK_OTHER_COMPILER_METADATA
            return HEAP_DALVIK_OTHER_ACCOUNTING
        return HEAP_UNKNOWN
    if name.strip():
        return HEAP_UNKNOWN_MAP
    return HEAP_UNKNOWN


# ── smaps parser ──

class SmapsParser:
    def __init__(self):
        self.pss_sum = [0] * _NUM_HEAP
        self.pss_count = [0] * _NUM_HEAP
        self.swap_pss_count = [0] * _NUM_HEAP
        self.type_entries = [{} for _ in range(_NUM_HEAP)]

    def parse_text(self, text):
        lines = text.splitlines()
        idx = 0
        heap_type = HEAP_UNKNOWN
        name = ""

        while idx < len(lines):
            line = lines[idx]
            head_match = _HEAD_RE.match(line)
            if head_match:
                name = head_match.group(8)
                heap_type = _classify_mapping(name)

            idx += 1
            while idx < len(lines):
                line = lines[idx]
                pss_match = _PSS_RE.match(line)
                swap_match = _SWAP_PSS_RE.match(line)

                if pss_match or swap_match:
                    pss = 0
                    if pss_match:
                        pss = int(pss_match.group(1))
                        self.pss_count[heap_type] += pss
                    if swap_match:
                        pss = int(swap_match.group(1))
                        self.swap_pss_count[heap_type] += pss
                    if pss > 0:
                        self.pss_sum[heap_type] += pss
                        entries = self.type_entries[heap_type]
                        entries[name] = entries.get(name, 0) + pss
                elif _HEAD_RE.match(line):
                    break
                idx += 1

            if idx >= len(lines):
                break

    def write_txt(self, output_path, memory_type="ALL", simple=False):
        if memory_type != "ALL":
            if memory_type not in PSS_TYPE:
                print("Invalid memory type: %s" % memory_type)
                return
            type_index = PSS_TYPE.index(memory_type)
        else:
            type_index = -1

        with open(output_path, "w") as f:
            if type_index == -1:
                for i in range(_NUM_HEAP):
                    f.write("%s : %.3f M\n" % (PSS_TYPE[i], float(self.pss_sum[i]) / 1000))
                    f.write("\tpss: %.3f M\n" % (float(self.pss_count[i]) / 1000))
                    f.write("\tswapPss: %.3f M\n" % (float(self.swap_pss_count[i]) / 1000))
                    if not simple:
                        entries = self.type_entries[i]
                        count = Counter(entries)
                        for entry_name, entry_size in count.most_common():
                            f.write("\t\t%s : %d kB\n" % (entry_name, entry_size))
            else:
                f.write("%s : %.3f M\n" % (PSS_TYPE[type_index], float(self.pss_sum[type_index]) / 1000))
                f.write("\tpss: %.3f M\n" % (float(self.pss_count[type_index]) / 1000))
                f.write("\tswapPss: %.3f M\n" % (float(self.swap_pss_count[type_index]) / 1000))
                if not simple:
                    entries = self.type_entries[type_index]
                    count = Counter(entries)
                    for entry_name, entry_size in count.most_common():
                        f.write("\t\t%s : %d kB\n" % (entry_name, entry_size))

    def write_xls(self, output_path, memory_type="ALL", simple=False):
        if not HAS_XLSX:
            print("xlsxwriter not installed, cannot generate Excel")
            return

        if memory_type != "ALL":
            if memory_type not in PSS_TYPE:
                print("Invalid memory type: %s" % memory_type)
                return
            type_index = PSS_TYPE.index(memory_type)
        else:
            type_index = -1

        with pd.ExcelWriter(output_path, engine="xlsxwriter") as writer:
            if type_index == -1:
                for i in range(_NUM_HEAP):
                    type_name = PSS_TYPE[i]
                    if not simple:
                        names, data = self._build_sheet_data(i)
                        DataFrame({"Name": names, "Memory": data}).to_excel(writer, sheet_name=type_name)
            else:
                if not simple:
                    names, data = self._build_sheet_data(type_index)
                    DataFrame({"Name": names, "Memory": data}).to_excel(writer, sheet_name=memory_type)

    def _build_sheet_data(self, type_index):
        entries = self.type_entries[type_index]
        count = Counter(entries)
        names = []
        data = []
        for entry_name, entry_size in count.most_common():
            names.append(entry_name)
            data.append(entry_size)
        names.append("swapPss")
        data.append(str(float(self.swap_pss_count[type_index])) + " Kb")
        names.append("pss")
        data.append(str(float(self.pss_count[type_index])) + " Kb")
        names.append("All")
        data.append(str(float(self.pss_sum[type_index])) + " Kb")
        return names, data

    def summary(self):
        """Return a dict of non-zero heap types with their PSS totals."""
        result = {}
        for i in range(_NUM_HEAP):
            if self.pss_sum[i] > 0:
                result[PSS_TYPE[i]] = {
                    "total_mb": round(float(self.pss_sum[i]) / 1000, 3),
                    "pss_mb": round(float(self.pss_count[i]) / 1000, 3),
                    "swap_pss_mb": round(float(self.swap_pss_count[i]) / 1000, 3),
                }
        return result


# ── adb helpers ──

def adb_shell(cmd, timeout=10):
    try:
        result = subprocess.run(
            ["adb", "shell"] + cmd,
            capture_output=True, text=True, timeout=timeout
        )
        return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def adb_shell_raw(cmd, timeout=10):
    try:
        result = subprocess.run(
            ["adb", "shell"] + cmd,
            capture_output=True, text=True, timeout=timeout
        )
        return result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def get_pid_by_name(process_name):
    output = adb_shell(["pidof", "-s", process_name])
    output = output.strip().replace("\r", "")
    if output and output.isdigit():
        return int(output)
    return None


def read_proc_status(pid):
    """Read /proc/pid/status, return dict with VmRSS, VmHWM in kB."""
    text = adb_shell(["cat", "/proc/%d/status" % pid])
    result = {"vmrss_kb": 0, "vmhwm_kb": 0}
    for line in text.splitlines():
        if line.startswith("VmRSS:"):
            result["vmrss_kb"] = int(line.split()[1])
        elif line.startswith("VmHWM:"):
            result["vmhwm_kb"] = int(line.split()[1])
    return result


def read_cpu_percent(pid):
    """Get CPU% for a pid via ps command."""
    try:
        text = adb_shell(["ps", "-p", str(pid), "-o", "%CPU"])
        if not text:
            return 0.0
        lines = text.strip().splitlines()
        if len(lines) >= 2:
            # Second line is the value
            return float(lines[1].strip())
    except (ValueError, IndexError):
        pass
    return 0.0


def read_process_stats(pid):
    """Read VmRSS, VmHWM and CPU% in a single adb shell command."""
    cmd = f'cat /proc/{pid}/status | grep -E "^(VmRSS|VmHWM):"; ps -p {pid} -o %CPU | tail -1'
    text = adb_shell([cmd])
    result = {"vmrss_kb": 0, "vmhwm_kb": 0, "cpu_percent": 0.0}
    
    lines = text.strip().splitlines()
    for line in lines:
        if line.startswith("VmRSS:"):
            result["vmrss_kb"] = int(line.split()[1])
        elif line.startswith("VmHWM:"):
            result["vmhwm_kb"] = int(line.split()[1])
        else:
            # CPU% line
            try:
                result["cpu_percent"] = float(line.strip())
            except ValueError:
                pass
    
    return result


def read_smaps(pid):
    """Read /proc/pid/smaps via adb."""
    return adb_shell_raw(["cat", "/proc/%d/smaps" % pid], timeout=30)


def process_alive(pid):
    """Check if process exists by reading /proc/<pid>/status"""
    try:
        result = subprocess.run(
            ["adb", "shell", "cat", "/proc/%d/status" % pid],
            capture_output=True, text=True, timeout=5
        )
        # If we get any output, process exists
        return len(result.stdout.strip()) > 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


# ── Monitor ──

class ProcessMonitor:
    def __init__(self, pid, interval=0.5, output_dir=None, output_format="txt",
                 collect_smaps=True, smaps_interval=None):
        self.pid = pid
        self.interval = interval
        self.collect_smaps = collect_smaps
        self.smaps_interval = smaps_interval
        self.output_format = output_format

        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        if output_dir:
            self.output_dir = output_dir
        else:
            self.output_dir = "smaps_monitor_pid%d_%s" % (pid, timestamp)
        os.makedirs(self.output_dir, exist_ok=True)

        self.trend_path = os.path.join(self.output_dir, "trend.csv")
        self.summary_path = os.path.join(self.output_dir, "summary.txt")

        self.peak_vmrss = 0
        self.peak_vmhwm = 0
        self.peak_cpu = 0.0
        self.last_vmrss = 0
        self.sample_count = 0
        self.smaps_snapshots = []
        
        # 初始值和平均值计算
        self.initial_vmrss = None
        self.initial_vmhwm = None
        self.initial_cpu = None
        self.sum_vmrss = 0
        self.sum_vmhwm = 0
        self.sum_cpu = 0.0

    def run(self, duration=None):
        print("Monitoring PID %d (interval=%.1fs, output=%s)" % (self.pid, self.interval, self.output_dir))
        print("Output directory: %s" % os.path.abspath(self.output_dir))

        with open(self.trend_path, "w") as trend_file:
            trend_file.write("timestamp_ms,vmrss_kb,vmhwm_kb,cpu_percent\n")

            start_time = time.time()
            last_smaps_time = 0

            while True:
                if duration and (time.time() - start_time) >= duration:
                    break

                if not process_alive(self.pid):
                    print("Process %d exited" % self.pid)
                    break

                stats = read_process_stats(self.pid)
                vmrss = stats["vmrss_kb"]
                vmhwm = stats["vmhwm_kb"]
                cpu = stats["cpu_percent"]

                # 记录初始值
                if self.initial_vmrss is None:
                    self.initial_vmrss = vmrss
                    self.initial_vmhwm = vmhwm
                    self.initial_cpu = cpu

                # 累加用于计算平均值
                self.sum_vmrss += vmrss
                self.sum_vmhwm += vmhwm
                self.sum_cpu += cpu

                self.last_vmrss = vmrss
                if vmrss > self.peak_vmrss:
                    self.peak_vmrss = vmrss
                if vmhwm > self.peak_vmhwm:
                    self.peak_vmhwm = vmhwm
                if cpu > self.peak_cpu:
                    self.peak_cpu = cpu

                ts_ms = int(time.time() * 1000)
                trend_file.write("%d,%d,%d,%.1f\n" % (ts_ms, vmrss, vmhwm, cpu))
                trend_file.flush()

                self.sample_count += 1

                # Collect smaps snapshot
                if self.collect_smaps:
                    should_collect = False
                    if self.smaps_interval:
                        if time.time() - last_smaps_time >= self.smaps_interval:
                            should_collect = True
                    elif len(self.smaps_snapshots) == 0:
                        should_collect = True

                    if should_collect:
                        smaps_text = read_smaps(self.pid)
                        if smaps_text:
                            snapshot_idx = len(self.smaps_snapshots)
                            snapshot_path = os.path.join(
                                self.output_dir, "smaps_raw_%d.txt" % snapshot_idx)
                            with open(snapshot_path, "w") as sf:
                                sf.write(smaps_text)

                            parser = SmapsParser()
                            parser.parse_text(smaps_text)
                            self.smaps_snapshots.append(parser)

                            ext = "xls" if self.output_format == "xls" and HAS_XLSX else "txt"
                            analysis_path = os.path.join(
                                self.output_dir, "smaps_analysis_%d.%s" % (snapshot_idx, ext))
                            if ext == "xls":
                                parser.write_xls(analysis_path)
                            else:
                                parser.write_txt(analysis_path)

                            print("  [%d] VmRSS=%d kB, VmHWM=%d kB, CPU=%.1f%%, smaps snapshot #%d saved"
                                  % (self.sample_count, vmrss, vmhwm, cpu, snapshot_idx))
                            last_smaps_time = time.time()
                        else:
                            print("  [%d] VmRSS=%d kB, VmHWM=%d kB, CPU=%.1f%% (smaps read failed)"
                                  % (self.sample_count, vmrss, vmhwm, cpu))
                    else:
                        print("  [%d] VmRSS=%d kB, VmHWM=%d kB, CPU=%.1f%%"
                              % (self.sample_count, vmrss, vmhwm, cpu))
                else:
                    print("  [%d] VmRSS=%d kB, VmHWM=%d kB, CPU=%.1f%%"
                          % (self.sample_count, vmrss, vmhwm, cpu))

                time.sleep(self.interval)

        self._write_summary()
        self._print_summary()

    def _write_summary(self):
        with open(self.summary_path, "w") as f:
            f.write("PID: %d\n" % self.pid)
            f.write("Samples: %d\n" % self.sample_count)
            
            # 初始值
            if self.initial_vmrss is not None:
                f.write("\nInitial Values:\n")
                f.write("  VmRSS: %d kB (%.2f MB)\n" % (self.initial_vmrss, self.initial_vmrss / 1024))
                f.write("  VmHWM: %d kB (%.2f MB)\n" % (self.initial_vmhwm, self.initial_vmhwm / 1024))
                f.write("  CPU: %.1f%%\n" % self.initial_cpu)
            
            # 平均值
            if self.sample_count > 0:
                avg_vmrss = self.sum_vmrss / self.sample_count
                avg_vmhwm = self.sum_vmhwm / self.sample_count
                avg_cpu = self.sum_cpu / self.sample_count
                f.write("\nAverage Values:\n")
                f.write("  VmRSS: %.2f kB (%.2f MB)\n" % (avg_vmrss, avg_vmrss / 1024))
                f.write("  VmHWM: %.2f kB (%.2f MB)\n" % (avg_vmhwm, avg_vmhwm / 1024))
                f.write("  CPU: %.1f%%\n" % avg_cpu)
            
            f.write("\nPeak Values:\n")
            f.write("  VmRSS: %d kB (%.2f MB)\n" % (self.peak_vmrss, self.peak_vmrss / 1024))
            f.write("  VmHWM: %d kB (%.2f MB)\n" % (self.peak_vmhwm, self.peak_vmhwm / 1024))
            f.write("  CPU: %.1f%%\n" % self.peak_cpu)
            
            f.write("\nLast Values:\n")
            f.write("  VmRSS: %d kB (%.2f MB)\n" % (self.last_vmrss, self.last_vmrss / 1024))
            f.write("\n")

            # Machine-readable summary markers (compatible with run.sh grep)
            f.write("PEAK_VMHWM_KB=%d\n" % self.peak_vmhwm)
            f.write("LAST_VMRSS_KB=%d\n" % self.last_vmrss)
            f.write("PEAK_CPU_PERCENT=%d\n" % int(self.peak_cpu))
            
            # 初始值和平均值的机器可读格式
            if self.initial_vmrss is not None:
                f.write("INITIAL_VMRSS_KB=%d\n" % self.initial_vmrss)
                f.write("INITIAL_VMHWM_KB=%d\n" % self.initial_vmhwm)
                f.write("INITIAL_CPU_PERCENT=%d\n" % int(self.initial_cpu))
            
            if self.sample_count > 0:
                f.write("AVG_VMRSS_KB=%d\n" % int(self.sum_vmrss / self.sample_count))
                f.write("AVG_VMHWM_KB=%d\n" % int(self.sum_vmhwm / self.sample_count))
                f.write("AVG_CPU_PERCENT=%d\n" % int(self.sum_cpu / self.sample_count))

            if self.smaps_snapshots:
                f.write("\nSmaps Analysis (last snapshot)\n")
                f.write("-" * 40 + "\n")
                last = self.smaps_snapshots[-1]
                for type_name, info in last.summary().items():
                    f.write("  %s: %.3f MB (pss=%.3f, swapPss=%.3f)\n"
                            % (type_name, info["total_mb"], info["pss_mb"], info["swap_pss_mb"]))

    def _print_summary(self):
        print("")
        print("=" * 50)
        print("Monitor Summary (PID %d)" % self.pid)
        print("=" * 50)
        print("Samples: %d" % self.sample_count)
        
        # 初始值
        if self.initial_vmrss is not None:
            print("\nInitial Values:")
            print("  VmRSS: %.2f MB" % (self.initial_vmrss / 1024))
            print("  VmHWM: %.2f MB" % (self.initial_vmhwm / 1024))
            print("  CPU:   %.1f%%" % self.initial_cpu)
        
        # 平均值
        if self.sample_count > 0:
            avg_vmrss = self.sum_vmrss / self.sample_count
            avg_vmhwm = self.sum_vmhwm / self.sample_count
            avg_cpu = self.sum_cpu / self.sample_count
            print("\nAverage Values:")
            print("  VmRSS: %.2f MB" % (avg_vmrss / 1024))
            print("  VmHWM: %.2f MB" % (avg_vmhwm / 1024))
            print("  CPU:   %.1f%%" % avg_cpu)
        
        print("\nPeak Values:")
        print("  VmRSS: %.2f MB" % (self.peak_vmrss / 1024))
        print("  VmHWM: %.2f MB" % (self.peak_vmhwm / 1024))
        print("  CPU:   %.1f%%" % self.peak_cpu)
        
        print("\nLast Values:")
        print("  VmRSS: %.2f MB" % (self.last_vmrss / 1024))
        
        if self.smaps_snapshots:
            print("\nSmaps snapshots: %d" % len(self.smaps_snapshots))
        print("Output: %s" % os.path.abspath(self.output_dir))


# ── CLI ──

def parse_args():
    parser = argparse.ArgumentParser(
        description="Android process memory/CPU monitor + smaps analyzer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Monitor PID 1234, poll every 0.5s
  %(prog)s -p 1234

  # Monitor by process name, wait for it to appear
  %(prog)s -n com.example.app --wait

  # One-shot smaps analysis (no monitoring)
  %(prog)s -p 1234 --once

  # Monitor with smaps snapshot every 5s
  %(prog)s -p 1234 --smaps-interval 5

  # Output as Excel
  %(prog)s -p 1234 -o xls
""")
    parser.add_argument("-p", "--pid", type=int, help="target process PID")
    parser.add_argument("-n", "--name", help="target process name (resolved via pidof)")
    parser.add_argument("--wait", action="store_true", help="wait for process to appear")
    parser.add_argument("--interval", type=float, default=0.3, help="polling interval in seconds (default: 0.3)")
    parser.add_argument("--duration", type=float, default=None, help="max monitoring duration in seconds")
    parser.add_argument("--once", action="store_true", help="one-shot smaps analysis, no monitoring loop")
    parser.add_argument("--smaps-interval", type=float, default=None,
                        help="collect smaps snapshot every N seconds (default: once at start)")
    parser.add_argument("--no-smaps", action="store_true", help="skip smaps collection")
    parser.add_argument("-o", "--output", default="txt", choices=["txt", "xls"],
                        help="output format for smaps analysis (default: txt)")
    parser.add_argument("-d", "--dir", help="output directory (default: auto-generated)")
    parser.add_argument("-s", "--simple", action="store_true", help="simple output (no per-mapping details)")
    return parser.parse_args()


def main():
    args = parse_args()

    pid = args.pid
    if args.name:
        if args.wait:
            print("Waiting for process: %s ..." % args.name)
            while True:
                pid = get_pid_by_name(args.name)
                if pid:
                    break
                time.sleep(0.5)
        else:
            pid = get_pid_by_name(args.name)
            if not pid:
                print("Process not found: %s" % args.name)
                sys.exit(1)

    if not pid:
        print("Please provide --pid or --name")
        sys.exit(1)

    print("Target PID: %d" % pid)

    if args.once:
        # One-shot mode: just collect and analyze smaps
        smaps_text = read_smaps(pid)
        if not smaps_text:
            print("Failed to read /proc/%d/smaps" % pid)
            sys.exit(1)

        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = args.dir or "smaps_once_pid%d_%s" % (pid, timestamp)
        os.makedirs(output_dir, exist_ok=True)

        raw_path = os.path.join(output_dir, "smaps_raw.txt")
        with open(raw_path, "w") as f:
            f.write(smaps_text)

        parser = SmapsParser()
        parser.parse_text(smaps_text)

        ext = "xls" if args.output == "xls" and HAS_XLSX else "txt"
        analysis_path = os.path.join(output_dir, "smaps_analysis.%s" % ext)
        if ext == "xls":
            parser.write_xls(analysis_path, simple=args.simple)
        else:
            parser.write_txt(analysis_path, simple=args.simple)

        print("Output: %s" % os.path.abspath(output_dir))
        print("Peak VmHWM: %.2f MB" % (read_proc_status(pid)["vmhwm_kb"] / 1024))
        return

    monitor = ProcessMonitor(
        pid=pid,
        interval=args.interval,
        output_dir=args.dir,
        output_format=args.output,
        collect_smaps=not args.no_smaps,
        smaps_interval=args.smaps_interval,
    )
    monitor.run(duration=args.duration)


if __name__ == "__main__":
    main()
