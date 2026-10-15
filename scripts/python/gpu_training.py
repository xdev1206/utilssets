#!/usr/bin/env python3
"""Randomly load one visible NVIDIA GPU with configurable load variation.

Requires a CUDA-enabled PyTorch installation. The process runs until Ctrl-C or
until --duration seconds have elapsed (3 hours by default).
"""

from __future__ import annotations

import argparse
import math
import random
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--gpu",
        type=int,
        default=None,
        help="visible GPU index; randomly selected when omitted",
    )
    parser.add_argument(
        "--memory-fraction",
        type=float,
        default=0.05,
        help="target total VRAM usage fraction (default: 0.05)",
    )
    parser.add_argument(
        "--gpu-utilization",
        type=float,
        default=0.20,
        help="target average GPU utilization fraction (default: 0.20)",
    )
    parser.add_argument(
        "--variation",
        type=float,
        default=0.05,
        help="symmetric target variation fraction (default: 0.05)",
    )
    parser.add_argument(
        "--adjust-interval",
        type=float,
        default=30,
        help="seconds between target changes (default: 30)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=3 * 60 * 60,
        help="run time in seconds; 0 means run until interrupted (default: 3 hours)",
    )
    return parser.parse_args()


def load_memory(torch, device, target_fraction: float):
    total_bytes = torch.cuda.get_device_properties(device).total_memory
    free_bytes, _ = torch.cuda.mem_get_info(device)
    used_bytes = total_bytes - free_bytes
    target_bytes = math.ceil(total_bytes * target_fraction)
    bytes_to_allocate = max(0, target_bytes - used_bytes)

    # Allocate in chunks so a failed allocation can report a useful error.
    chunks = []
    chunk_size = 64 * 1024 * 1024
    try:
        while bytes_to_allocate > 0:
            allocation_size = min(chunk_size, bytes_to_allocate)
            block = torch.empty(
                allocation_size,
                dtype=torch.uint8,
                device=device,
            )
            block.fill_(0)
            chunks.append(block)
            bytes_to_allocate -= allocation_size
    except RuntimeError as error:
        del chunks
        raise RuntimeError(
            "unable to allocate enough VRAM to exceed the requested "
            f"{target_fraction:.0%} target; another process may be using "
            "the GPU"
        ) from error

    return chunks, total_bytes


def adjust_memory(torch, device, blocks, total_bytes, target_fraction: float) -> None:
    free_bytes, _ = torch.cuda.mem_get_info(device)
    used_bytes = total_bytes - free_bytes
    target_bytes = math.ceil(total_bytes * target_fraction)

    if used_bytes < target_bytes:
        bytes_to_allocate = target_bytes - used_bytes
        chunk_size = 64 * 1024 * 1024
        try:
            while bytes_to_allocate > 0:
                allocation_size = min(chunk_size, bytes_to_allocate)
                block = torch.empty(
                    allocation_size,
                    dtype=torch.uint8,
                    device=device,
                )
                block.fill_(0)
                blocks.append(block)
                bytes_to_allocate -= allocation_size
        except RuntimeError:
            print("Warning: unable to raise VRAM usage to the new target", flush=True)
    elif used_bytes > target_bytes:
        while blocks and used_bytes > target_bytes:
            del blocks[-1]
            torch.cuda.empty_cache()
            free_bytes, _ = torch.cuda.mem_get_info(device)
            used_bytes = total_bytes - free_bytes


def run_load(
    torch,
    device,
    duration: float,
    target_utilization: float,
    target_memory_fraction: float,
    variation: float,
    adjust_interval: float,
    memory_blocks,
    total_bytes,
) -> None:
    started_at = time.monotonic()
    next_report_at = started_at
    matrix = None
    right = None
    result = None
    next_adjust_at = started_at
    workload_cycles_remaining = 0
    dimension = 2048
    current_utilization = target_utilization

    while duration <= 0 or time.monotonic() - started_at < duration:
        now = time.monotonic()
        if now >= next_adjust_at:
            target_memory = random.uniform(
                max(0.0, target_memory_fraction - variation),
                min(0.89, target_memory_fraction + variation),
            )
            adjust_memory(torch, device, memory_blocks, total_bytes, target_memory)
            current_utilization = random.uniform(
                max(0.01, target_utilization - variation),
                min(1.0, target_utilization + variation),
            )
            next_adjust_at = now + adjust_interval

        if workload_cycles_remaining == 0:
            dimension = random.choice((2048, 3072, 4096))
            workload_cycles_remaining = 3

        matrix = torch.randn(
            (dimension, dimension), device=device, dtype=torch.float16
        )
        right = torch.randn_like(matrix)
        result = torch.empty_like(matrix)

        compute_started_at = time.monotonic()
        for _ in range(random.randint(4, 12)):
            torch.mm(matrix, right, out=result)
        torch.cuda.synchronize(device)
        compute_seconds = time.monotonic() - compute_started_at
        time.sleep(compute_seconds * (1 - current_utilization) / current_utilization)
        workload_cycles_remaining -= 1

        now = time.monotonic()
        if now >= next_report_at:
            free_bytes, total_bytes = torch.cuda.mem_get_info(device)
            used_fraction = 1 - free_bytes / total_bytes
            print(
                f"VRAM usage: {used_fraction:.1%}; "
                f"GPU target: {current_utilization:.1%}",
                flush=True,
            )
            next_report_at = now + 5


def main() -> int:
    args = parse_args()
    if not 0 < args.memory_fraction < 0.90:
        raise SystemExit("--memory-fraction must be greater than 0 and below 0.90")
    if not 0 < args.gpu_utilization <= 1:
        raise SystemExit("--gpu-utilization must be greater than 0 and at most 1")
    if not 0 <= args.variation < 1:
        raise SystemExit("--variation must be non-negative and below 1")
    if args.adjust_interval <= 0:
        raise SystemExit("--adjust-interval must be greater than 0")
    if args.duration < 0:
        raise SystemExit("--duration must be non-negative")

    try:
        import torch
    except ImportError as error:
        raise SystemExit("PyTorch is required: install a CUDA-enabled PyTorch build") from error

    if not torch.cuda.is_available():
        raise SystemExit("CUDA is unavailable; an NVIDIA GPU and CUDA-enabled PyTorch are required")

    gpu_count = torch.cuda.device_count()
    gpu_index = args.gpu if args.gpu is not None else random.randrange(gpu_count)
    if not 0 <= gpu_index < gpu_count:
        raise SystemExit(f"--gpu must be between 0 and {gpu_count - 1}")

    device = torch.device(f"cuda:{gpu_index}")
    torch.cuda.set_device(device)
    name = torch.cuda.get_device_name(device)
    print(f"GPU: {gpu_index} ({name})")
    print(
        f"Target VRAM usage: {args.memory_fraction:.1%} +/- "
        f"{args.variation:.1%}, adjusted every {args.adjust_interval:g}s"
    )
    print(
        f"Target average GPU utilization: {args.gpu_utilization:.1%} +/- "
        f"{args.variation:.1%}, adjusted every {args.adjust_interval:g}s"
    )

    reserved_blocks, total_bytes = load_memory(torch, device, args.memory_fraction)
    try:
        run_load(
            torch,
            device,
            args.duration,
            args.gpu_utilization,
            args.memory_fraction,
            args.variation,
            args.adjust_interval,
            reserved_blocks,
            total_bytes,
        )
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        del reserved_blocks
        torch.cuda.empty_cache()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
