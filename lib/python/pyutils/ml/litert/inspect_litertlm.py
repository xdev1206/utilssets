#!/usr/bin/env python3
"""Inspect, unpack, and summarize a LiteRT-LM .litertlm bundle."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("model", type=Path, help="Path to the .litertlm bundle")
  parser.add_argument(
      "--output-dir",
      type=Path,
      help="Unpack directory (default: <model-stem>_unpacked)",
  )
  return parser.parse_args()


def summarize_tflite(path: Path) -> dict[str, object]:
  """Reads TFLite subgraph/signature information without executing the model."""
  try:
    from ai_edge_litert.interpreter import Interpreter

    interpreter = Interpreter(model_path=str(path))
    signatures = interpreter.get_signature_list()
    return {
        "path": str(path),
        "size_bytes": path.stat().st_size,
        "signature_count": len(signatures),
        "signatures": signatures,
        "status": "ok",
    }
  except Exception as error:  # Keep other sections inspectable if one is unsupported.
    return {
        "path": str(path),
        "size_bytes": path.stat().st_size,
        "status": "error",
        "error": f"{type(error).__name__}: {error}",
    }


def main() -> None:
  args = parse_args()
  model = args.model.expanduser().resolve()
  if not model.is_file():
    raise SystemExit(f"model does not exist: {model}")
  output_dir = (args.output_dir or model.with_name(model.stem + "_unpacked")).resolve()
  output_dir.mkdir(parents=True, exist_ok=True)

  from litert_lm_builder import unpack_litertlm_file
  from litert_torch.generative.export_hf.experimental.litertlm_bundle import (
      litertlm_bundle,
  )

  # 1. Print the bundle-level summary.
  print("=== bundle summary ===")
  print(litertlm_bundle.peek_litertlm(str(model)))

  # 2. Unpack all sections and print the file manifest.
  unpack_litertlm_file(str(model), str(output_dir))
  files = sorted(path for path in output_dir.iterdir() if path.is_file())
  print("=== unpacked files ===")
  for path in files:
    print(f"{path.name}\t{path.stat().st_size} bytes")

  # 3. Parse every TFLite section through the LiteRT interpreter.
  tflite_summaries = [
      summarize_tflite(path)
      for path in files
      if path.suffix == ".tflite"
  ]
  report = {
      "model": str(model),
      "bundle_size_bytes": model.stat().st_size,
      "unpacked_dir": str(output_dir),
      "tflite_sections": tflite_summaries,
  }
  report_path = output_dir / "inspect_report.json"
  report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
  print("=== TFLite summaries ===")
  print(json.dumps(tflite_summaries, indent=2, ensure_ascii=False))
  print(f"=== report ===\n{report_path}")


if __name__ == "__main__":
  main()
