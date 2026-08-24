#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import time
import re
import shlex
import argparse
import os
from statistics import mean

PHONE_BASE = "/data/local/tmp/llm_sdk"
PHONE_PATH = "/data/local/tmp/llm_sdk/assets_gemma3-1B"

DEFAULT_REMOTE_CONFIG = "config_gemma3_1b.yaml"
DEFAULT_REMOTE_PROMPT = "sample_prompt_introduce.txt"
MAX_RESPONSE = "512"
PREFORMATTER = "GemmaNoInput"

POLL_INTERVAL = 0.5  # seconds
VERBOSE = False


def log_info(msg):
    print(f"[INFO] {msg}")


def log_warn(msg):
    print(f"[WARN] {msg}")


def log_debug(msg):
    if VERBOSE:
        print(f"[DEBUG] {msg}")


def run_cmd(cmd, check=True, capture_output=True, text=True):
    log_debug(f"CMD: {cmd}")
    return subprocess.run(
        cmd,
        shell=True,
        check=check,
        capture_output=capture_output,
        text=text,
    )


def adb_shell(cmd, check=True):
    full_cmd = f'adb shell {shlex.quote(cmd)}'
    return run_cmd(full_cmd, check=check)


def adb_push(local_path, remote_dir):
    cmd = f'adb push "{local_path}" "{remote_dir}"'
    log_info(f"Pushing file: {local_path} -> {remote_dir}")
    return run_cmd(cmd)


def create_dirs():
    log_info("Creating directories on device...")
    adb_shell(f"mkdir -p {PHONE_BASE}")
    adb_shell(f"mkdir -p {PHONE_PATH}")
    log_info(f"Directories ready: {PHONE_BASE}, {PHONE_PATH}")


def chmod_main():
    log_info("Setting execute permission for main...")
    adb_shell(f"chmod +x {PHONE_BASE}/main")
    log_info("chmod completed.")


def find_pid():
    log_info("Trying to find remote PID...")

    try:
        result = adb_shell(f"pidof {PHONE_BASE}/main", check=False)
        output = (result.stdout or "").strip()
        log_debug(f"pidof output: {output}")
        if output:
            pid = output.split()[0]
            if pid.isdigit():
                log_info(f"PID found by pidof: {pid}")
                return pid
    except Exception as e:
        log_warn(f"pidof failed: {e}")

    try:
        result = adb_shell(f'ps -A | grep "{PHONE_BASE}/main"', check=False)
        output = (result.stdout or "").strip()
        log_debug(f"ps grep output: {output}")
        if output:
            for line in output.splitlines():
                parts = line.split()
                for item in parts:
                    if item.isdigit():
                        log_info(f"PID found by ps/grep: {item}")
                        return item
    except Exception as e:
        log_warn(f"ps/grep failed: {e}")

    log_warn("PID not found.")
    return None


def read_proc_stat(pid):
    try:
        result = adb_shell(f"cat /proc/{pid}/stat", check=False)
        stat_line = (result.stdout or "").strip()
        if not stat_line:
            return None

        rparen = stat_line.rfind(")")
        if rparen == -1:
            return None

        rest = stat_line[rparen + 2:].split()
        utime = int(rest[11])
        stime = int(rest[12])
        return utime + stime
    except Exception:
        return None


def read_proc_status_rss_kb(pid):
    try:
        result = adb_shell(f"cat /proc/{pid}/status", check=False)
        text = result.stdout or ""
        m = re.search(r"VmRSS:\s+(\d+)\s+kB", text)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return None


def get_dmabuf_userspace_pss_kb(pid):
    log_info(f"Running dmabuf_dump for pid={pid} ...")
    try:
        result = adb_shell(f"dmabuf_dump {pid}", check=False)
        text = (result.stdout or "") + (result.stderr or "")
        log_debug(f"dmabuf_dump output: {text.strip()}")
        m = re.search(r"userspace_pss:\s*(\d+)\s*kB", text, re.IGNORECASE)
        if m:
            value = int(m.group(1))
            log_info(f"Parsed dmabuf userspace_pss: {value} kB")
            return value
        log_warn("userspace_pss not found in dmabuf_dump output.")
    except Exception as e:
        log_warn(f"dmabuf_dump failed: {e}")
    return 0


def is_process_alive(pid):
    try:
        result = adb_shell(f"test -d /proc/{pid} && echo alive || echo dead", check=False)
        return "alive" in (result.stdout or "")
    except Exception:
        return False


def format_rss(kb):
    if kb is None:
        return "n/a"
    if kb >= 1024 * 1024:
        return f"{kb / 1024 / 1024:.1f} GB"
    if kb >= 1024:
        return f"{kb / 1024:.1f} MB"
    return f"{kb} KB"


def parse_ctx_from_config(config_path):
    log_info(f"Parsing ctx from config: {config_path}")
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            content = f.read()

        patterns = [
            r"cache\s*size\s*:\s*([0-9]+)",
            r"cache_size\s*:\s*([0-9]+)",
            r"cache-size\s*:\s*([0-9]+)",
        ]

        for pattern in patterns:
            m = re.search(pattern, content, re.IGNORECASE)
            if m:
                ctx = m.group(1)
                log_info(f"Parsed ctx(cache size): {ctx}")
                return ctx
    except Exception as e:
        log_warn(f"Failed to parse ctx from config: {e}")

    log_warn("ctx not found in config, use n/a")
    return "n/a"


def parse_perf_from_output(output):
    log_info("Parsing performance metrics from program output...")

    prompt_ts = "n/a"
    gen_ts = "n/a"

    try:
        m1 = re.search(
            r"Prompt\s+Mode\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*tok/s",
            output,
            re.IGNORECASE,
        )
        if m1:
            prompt_ts = m1.group(1)

        m2 = re.search(
            r"Generative\s+Mode\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*tok/s",
            output,
            re.IGNORECASE,
        )
        if m2:
            gen_ts = m2.group(1)
    except Exception as e:
        log_warn(f"Failed to parse performance metrics: {e}")

    log_info(f"Parsed prompt_ts: {prompt_ts}")
    log_info(f"Parsed gen_ts: {gen_ts}")
    return prompt_ts, gen_ts


def monitor_process(pid, start_time):
    log_info(f"Start monitoring pid={pid} ...")
    CLK_TCK = 100.0

    cpu_samples = []
    rss_max_kb = None
    dmabuf_userspace_pss_kb = 0
    dmabuf_done = False
    sample_idx = 0

    prev_wall = time.time()
    prev_cpu = read_proc_stat(pid)

    while True:
        time.sleep(POLL_INTERVAL)

        if not is_process_alive(pid):
            log_info(f"Process pid={pid} exited.")
            break

        now = time.time()
        elapsed = now - start_time
        curr_cpu = read_proc_stat(pid)
        curr_rss = read_proc_status_rss_kb(pid)

        if curr_rss is not None:
            if rss_max_kb is None or curr_rss > rss_max_kb:
                rss_max_kb = curr_rss

        curr_cpu_pct = None
        if prev_cpu is not None and curr_cpu is not None:
            delta_cpu = curr_cpu - prev_cpu
            delta_wall = now - prev_wall
            if delta_wall > 0:
                curr_cpu_pct = (delta_cpu / CLK_TCK) / delta_wall * 100.0
                if curr_cpu_pct < 0:
                    curr_cpu_pct = 0.0
                cpu_samples.append(curr_cpu_pct)

        if (not dmabuf_done) and (elapsed >= 2.0):
            log_info(f"Elapsed {elapsed:.2f}s, trigger dmabuf_dump...")
            dmabuf_userspace_pss_kb = get_dmabuf_userspace_pss_kb(pid)
            dmabuf_done = True

        sample_idx += 1
        cpu_str = f"{curr_cpu_pct:.1f}%" if curr_cpu_pct is not None else "n/a"
        rss_str = f"{curr_rss} kB" if curr_rss is not None else "n/a"
        rss_max_str = f"{rss_max_kb} kB" if rss_max_kb is not None else "n/a"

        log_debug(
            f"sample={sample_idx}, elapsed={elapsed:.2f}s, "
            f"cpu={cpu_str}, vmrss={rss_str}, vmrss_max={rss_max_str}, "
            f"dmabuf_pss={dmabuf_userspace_pss_kb} kB"
        )

        prev_wall = now
        prev_cpu = curr_cpu

    end_time = time.time()
    duration = end_time - start_time

    final_rss_kb = None
    if rss_max_kb is not None:
        final_rss_kb = rss_max_kb + dmabuf_userspace_pss_kb

    log_info("Monitoring finished.")
    log_info(f"cpu_samples={len(cpu_samples)}")
    log_info(f"vmrss_max={rss_max_kb} kB")
    log_info(f"dmabuf_userspace_pss={dmabuf_userspace_pss_kb} kB")
    log_info(f"final_rss={final_rss_kb} kB")
    log_info(f"duration={duration:.2f}s")

    return {
        "cpu_avg": mean(cpu_samples) if cpu_samples else None,
        "cpu_max": max(cpu_samples) if cpu_samples else None,
        "rss_max_kb": final_rss_kb,
        "duration": duration,
        "dmabuf_userspace_pss_kb": dmabuf_userspace_pss_kb,
    }


def parse_args():
    parser = argparse.ArgumentParser(description="Run remote main via adb and collect metrics.")
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose debug logs",
    )
    parser.add_argument(
        "--config",
        default=None,
        help=f"Optional local config file path, if set it will be pushed to {PHONE_PATH}",
    )
    parser.add_argument(
        "--prompt",
        default=None,
        help=f"Optional local prompt file path, if set it will be pushed to {PHONE_PATH}",
    )
    return parser.parse_args()


def main():
    global VERBOSE

    args = parse_args()
    VERBOSE = args.verbose

    local_config = args.config
    local_prompt = args.prompt

    remote_config = DEFAULT_REMOTE_CONFIG
    remote_prompt = DEFAULT_REMOTE_PROMPT

    log_info("===== Script started =====")
    log_info(f"verbose={VERBOSE}")
    log_info(f"PHONE_BASE={PHONE_BASE}")
    log_info(f"PHONE_PATH={PHONE_PATH}")
    log_info(f"local_config={local_config}")
    log_info(f"local_prompt={local_prompt}")
    log_info(f"default_remote_config={DEFAULT_REMOTE_CONFIG}")
    log_info(f"default_remote_prompt={DEFAULT_REMOTE_PROMPT}")
    log_info(f"MAX_RESPONSE={MAX_RESPONSE}")
    log_info(f"PREFORMATTER={PREFORMATTER}")

    create_dirs()

    if local_config is not None:
        if not os.path.isfile(local_config):
            raise FileNotFoundError(f"Config file not found: {local_config}")
        remote_config = os.path.basename(local_config)
        adb_push(local_config, PHONE_PATH)
        log_info(f"Using pushed config: {remote_config}")
    else:
        log_info(f"No --config specified, use existing remote config: {remote_config}")

    if local_prompt is not None:
        if not os.path.isfile(local_prompt):
            raise FileNotFoundError(f"Prompt file not found: {local_prompt}")
        remote_prompt = os.path.basename(local_prompt)
        adb_push(local_prompt, PHONE_PATH)
        log_info(f"Using pushed prompt: {remote_prompt}")
    else:
        log_info(f"No --prompt specified, use existing remote prompt: {remote_prompt}")

    # 如果 main 也需要 push，可手动取消注释
    # adb_push("main", PHONE_BASE)

    chmod_main()

    ctx = parse_ctx_from_config(local_config) if local_config else "n/a"
    if local_config is None:
        log_info("No local config provided, ctx is set to n/a")

    remote_cmd = (
        f"cd {PHONE_PATH} && "
        f"export LD_LIBRARY_PATH=\\$LD_LIBRARY_PATH:{PHONE_BASE}:\\$PWD && "
        f"{PHONE_BASE}/main {remote_config} -i {remote_prompt} -m {MAX_RESPONSE} "
        f"--preformatter {PREFORMATTER}"
    )

    log_info("Launching main process...")
    log_debug(f"Remote command: {remote_cmd}")

    proc = subprocess.Popen(
        f'adb shell {shlex.quote(remote_cmd)}',
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    log_info("Waiting 1 second before querying pid...")
    time.sleep(1.0)

    pid = find_pid()
    start_time = time.time()

    if pid:
        log_info(f"Remote main pid = {pid}")
        metrics = monitor_process(pid, start_time)
    else:
        log_warn("Failed to get PID, some metrics will be n/a.")
        metrics = {
            "cpu_avg": None,
            "cpu_max": None,
            "rss_max_kb": None,
            "duration": None,
            "dmabuf_userspace_pss_kb": 0,
        }

    log_info("Waiting for main process output...")
    output, _ = proc.communicate()

    log_info("Program output received.")
    print("\n[PROGRAM OUTPUT BEGIN]")
    print(output)
    print("[PROGRAM OUTPUT END]\n")

    prompt_ts, gen_ts = parse_perf_from_output(output)

    cpu_model = "n/a"
    model_name = "gemma3-1B"
    t = "n/a"

    cpu_avg = f"{metrics['cpu_avg']:.1f}%" if metrics["cpu_avg"] is not None else "n/a"
    cpu_max = f"{metrics['cpu_max']:.1f}%" if metrics["cpu_max"] is not None else "n/a"
    rss_max = format_rss(metrics["rss_max_kb"])
    duration = f"{metrics['duration']:.2f}s" if metrics["duration"] is not None else "n/a"

    log_info(f"Final cpu_avg: {cpu_avg}")
    log_info(f"Final cpu_max: {cpu_max}")
    log_info(f"Final rss_max: {rss_max}")
    log_info(f"Final duration: {duration}")

    markdown_header = "| cpu_model | model_name | ctx | t | prompt_ts | gen_ts | cpu_avg | cpu_max | rss_max | duration |"
    markdown_align = "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"
    markdown_row = (
        f"| {cpu_model} | {model_name} | {ctx} | {t} | {prompt_ts} | {gen_ts} | "
        f"{cpu_avg} | {cpu_max} | {rss_max} | {duration} |"
    )

    print("[SUMMARY_MARKDOWN]")
    print(markdown_header)
    print(markdown_align)
    print(markdown_row)

    log_info("===== Script finished =====")


if __name__ == "__main__":
    main()
