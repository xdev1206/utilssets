# Gemma4 Embedding/PLE INT4 device bring-up (2026-10-22)

## Result

The rebooted TECNO_CO9m reconnects through the ADB proxy (`ADB_PORT=15037`, serial
`0826828000012855`). The clean cmdline-tool build can complete Gemma4 W4A16 with INT4
Embedding and INT4 PLE for a short prompt, but output is unusable gibberish. A longer
translation prompt crashes intermittently with SIGSEGV, so this is not yet a reliable
working configuration.

## Asset and runtime findings

- Asset directory: `assets/assets_gemma4_w4a16_embint4_pleint4_group64_np8_20261022/`;
  after removing diagnostic copies it occupies about 2.6 GB.
- Embedding LUT: G4LUTI4 group64, `262144x1536`, 226,492,512 bytes, decoded to INT16 using
  the graph input scale `0.0006681208033114672`.
- PLE LUT: G4LUTI4 group64, `262144x8960`, 1,321,205,856 bytes. Although the TFLite signature
  reports PLE as FP32, the compiled MDLA input buffer is 4,587,520 bytes for 256 tokens, so
  runtime input is 16-bit; the tested INT4 PLE header/YAML use FP16 output.
- `llm_cmdline_tool-v1.11.1` recognizes `plePath`; `pleEmbPath` is ignored. With `plePath`,
  shared DLA input registration matches 39/39. The YAML currently points to the shared PROM/
  GEN DLA files and external SHA weights.

## Device results

- A clean build, without diagnostic instrumentation, ran the short prompt `What is 2 plus 2?
  Answer briefly.` to completion (`rc=0`, about 19.6 generated tokens/s), but emitted repeated
  Hebrew tokens rather than a useful answer. Log: `verify_logs/device_w4a16_embint4_pleint4_group64_np8_20261022_clean_run2/`.
- The longer 104-token translation prompt crashed in a clean run. Log:
  `verify_logs/device_w4a16_embint4_pleint4_group64_np8_20261022_clean_run/`.
- A temporary diagnostic build showed both LUT lookups and backend prologue completing before
  the crash boundary at position/mask update. With detailed logging enabled, the same longer
  prompt completed but emitted repeated Japanese characters. Zeroing the embedding input also
  avoided the crash and emitted `<pad>` tokens. These changes only show timing/input sensitivity;
  they do not identify the root cause. Diagnostic code was removed and the clean binary was
  rebuilt and pushed afterward.
- INT8 Embedding + INT4 PLE completed one earlier probe, but returned only the turn terminator.
  Treat this as execution-path evidence, not a useful model result.

## Reproduction

```bash
ADB_PORT=15037 DEVBASE=/data/local/tmp/llm_cmdtool_g4v2 \
  bash scripts/device/run_gemma4_device.sh \
    --assets assets/assets_gemma4_w4a16_embint4_pleint4_group64_np8_20261022 \
    --yaml gemma4_e2b_device_ctx4096.yaml \
    --prompts verify_logs/screen_baselines/device_prompts_v2 \
    --out verify_logs/device_w4a16_embint4_pleint4_group64_np8_20261022 \
    --extra "--first-token-with-gen-model"
```

Short-prompt success does not establish stability for the full prompt set. The SIGSEGV
remains open and must be resolved before describing INT4/INT4 as a reliable device setup.

## Isolated group64 LUT query check (2026-10-23)

To separate LUT access from model execution, the same production `TokenEmbeddingLut` source was
cross-compiled for Android ARM64 and run on the phone without loading the LLM or invoking the NPU.
For each of 15 vocabulary rows (`0,1,2,7,8,63,64,127,128,255,256,65535,131071,200000,262143`),
the probe queried every column, covering all 24 Embedding groups and all 140 PLE groups, including
group64 boundaries.

- Embedding INT4 → INT16: `23,040` elements; Android output is bit-identical to host runtime and
  independent Python decoding (`0` mismatches; SHA-256
  `6e03a4e39b4956b63eec31e3f1723ab64b42b35efbadb948da1a05c1cd6781d1`).
- PLE INT4 → FP16: `134,400` elements; Android output is bit-identical to host runtime and
  independent Python decoding (`0` mismatches; SHA-256
  `5bf2980f8c360ae36b8d7261efd5640924c0f87a68164d864f4d798e932d43fa`).
- Android query process returned successfully for both files. Machine-readable details and raw
  query output are in `verify_logs/embedding_ple_int4_group64_query_20261023/`.

This clears the tested G4LUTI4 group64 parser, row lookup, grouped scales, nibble unpack, and output
conversion paths. The selected rows are sampled rather than an exhaustive pass over all 262,144
vocabulary rows; this probe also does not exercise how the NPU consumes the resulting buffers.
Therefore the model-level SIGSEGV remains a separate, unresolved issue.

## Long-prompt rerun (2026-10-23)

The same clean device configuration and 104-token translation prompt that had crashed was run
again. This run completed with `rc=0`, `crashed=false`, and about `20.69` generated tokens/s;
the reply contained only `<turn|>` and no answer body. Raw log and extracted result:
`verify_logs/device_w4a16_embint4_pleint4_group64_np8_20261023_sigsegv_recheck/`.

The earlier SIGSEGV did not reproduce in this rerun, but a single successful run does not clear
the prior failure. Treat the model execution as intermittent and the output as unusable until
repeated stability and response checks pass.

## Full screen prompt suite and LUT rerun (2026-10-23)

The full six-prompt set in `verify_logs/screen_baselines/device_prompts_v2/` was run again with
the clean W4A16 + Embedding INT4 + PLE INT4 device assets:

| Prompt | Return code | SIGSEGV | Generation speed | Output |
|---|---:|---:|---:|---|
| t0 | 139 | yes (signal 11) | — | none |
| t1 | 0 | no | 26.61 tok/s | repeated `の` characters |
| t2 | 139 | yes (signal 11) | — | none |
| t3 | 139 | yes (signal 11) | — | none |
| t4 | 0 | no | 23.66 tok/s | mixed/repeated invalid text |
| t5 | 139 | yes (signal 11) | — | none |

Result: 4/6 runs SIGSEGV with `rc=139`; 2/6 completed with unusable text. The same t0 prompt
completed once in the preceding single-prompt rerun and crashed in this suite, confirming
intermittent model-level execution failure.

The standalone group64 LUT checks were also repeated in this run. Host and Android ARM64 outputs
for Embedding and PLE matched independent Python decoding and each other bit-for-bit, with zero
mismatches across all columns of the 15 sampled rows. Details are in
`verify_logs/embedding_ple_int4_group64_query_20261023_all_tests/summary.json`. Model-suite logs
and per-prompt status are in `verify_logs/device_w4a16_embint4_pleint4_group64_np8_20261023_all_tests/`.

These results leave the standalone LUT query path passing while the full model path remains
unstable and produces unusable text. Do not mark this asset as a reliable working setup.

## 2026-10-22 PTQ-to-device rerun

The complete no-Hessian PTQ run was repeated with `mtk-converter 10.6.0` in the target
environment, followed by NP8 ctx4096 fix-shape, surgery, PROM cut, MDLA compile/extract,
G4LUTI4 export and asset push. The final asset was
`assets/assets_gemma-4-E2B-it_np8_g4luti4_ctx4096/`; its full package manifest is in the
[deployment artifact inventory](gemma4-deployment-artifacts-20261025.md).

The five-prompt run is recorded in
`verify_logs/device_g4luti4_np8_ctx4096_20261022_r1/`. Only `t1` returned `rc=0` and it
still produced gibberish (`prefill 709.991 tok/s`, `decode 24.1419 tok/s`); `t0/t2/t3/t4`
returned `rc=139` after model initialization and hot-swap. Resource samples were added to
the device runner: overall observed CPU peak was 152.00% and RSS peak was 517.33 MiB, but
these are diagnostic values because the run failed.

## Converter environment selection

The deployment scripts now select the converter from the caller-provided
`G4_PYTHON_ENV`, with that environment's `site-packages` prepended to `PYTHONPATH`.
This prevents a shared `PIP_TARGET`/`PYTHONPATH` entry such as `/workspace/xin.xu5/.local`
from shadowing the requested converter. For the current environment:

```bash
export G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env
source scripts/deploy/gemma4_v2/00_env.sh
python3 -c 'import mtk_converter; print(mtk_converter.__version__, mtk_converter.__file__)'
```

The verified result is `mtk_converter 10.6.0` from the selected environment. The
matching Python 3.12 wheel is from
`neuropilot-sdk-premium-10.0.2-build20260826/offline_tool/`; NumPy remains 1.26.4.

The current cut graph reports `input_embeds_0` as INT16 with scale
`0.0006681208033114672`, while `per_layer_emb_0` is FLOAT32 in the TFLite signature. The
INT16 PLE YAML variant is therefore not a valid final interface; the PLE path must use the
graph/runtime-compatible FP16 output variant. A PTQ-generated PLE G4LUTI4 file with FP16
output completed a single prompt, while full five-prompt runs remained prompt-dependent and
intermittently crashed. Raw FP16 PLE with G4LUTI4 embedding completed four of five prompts
in one rebooted run; a proper raw INT8 embedding control was also unstable. The remaining
blocker is current graph/runtime stability, not converter selection, PTQ completion, or MDLA
compilation. Do not report a partial run as a valid full benchmark.

## 2026-10-22 current FP16 package rerun

The new no-Hessian FP16 package is
`assets/assets_gemma-4-E2B-it_np8_ctx4096_20261022_170304/`, generated after PTQ with
`mtk_converter 10.6.0`, NP8 fix-shape, surgery, cut and MDLA compilation. Its YAML must be
passed explicitly as `--yaml gemma4_e2b_device_ctx4096.yaml`; omitting it selects the old
default YAML and only produces `YAML::BadFile`.

With the correct YAML, all five prompts reached model initialization, both token and PLE LUT
lookups completed, and then the first graph execute crashed with SIGSEGV (rc=139). There are
no valid prefill/decode timings for this run. The diagnostic resource summary is in
`verify_logs/device_ptq_env106_np8_ctx4096_20261022_correct/resource_summary.md`; because all
five runs crashed, its CPU/RSS values must not be treated as benchmark results.

Using the historical INT16 package with the newly rebuilt runtime fails earlier with
`expectedNumInputs=38, actualNumInputs=39`. This is an interface/graph-generation mismatch:
the current runtime's `plePath` path is distinct from the legacy `pleEmbPath` path and the old
asset is not a valid control for the new runtime. It does not implicate the converter.

## 2026-10-23 resource sampling rerun

The device runner now samples `/proc/<pid>/status` every nominal 300 ms and records
`VmRSS`, `VmHWM`, `VmPeak`, `RssAnon`, `RssFile`, and `RssShmem`. `smaps_rollup` provides
independent `Rss`/`Pss` cross-checks every fourth sample because reading it on every loop
would stretch the interval. CPU jiffies are summed across all process threads in one awk
pass. The measured interval after this optimization is 351--422 ms (about 360--381 ms
average), rather than the earlier one-second sampling.

The rerun showed that earlier low t2/t4 RSS values were undersampling artifacts. Successful
records measured RSS peaks of 615--895 MiB, PSS peaks of 652--919 MiB, and VmHWM around
1257 MiB. `VmPeak` is virtual address peak and reached about 19--20 GiB; it must not be
interpreted as resident memory. MDLA/DMA buffers are not included in process VmRSS/PSS and
need platform-specific counters for a complete device-wide memory figure.

## Final environment and stable device control

The remaining legacy PTQ helper `merge_fresh500_and_ptq.sh` was also migrated from its
hard-coded Conda/PYTHONPATH to the common `00_env.sh` entry point. It now invokes
`$G4_PYTHON_ENV/bin/mtk_ptq_llm` directly. Verification with
`G4_PYTHON_ENV=/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env` loads
`mtk_converter 10.6.0` from that environment's Python 3.12 site-packages; NumPy 1.26.4
was not treated as a blocker.

The stable final device control is the self-contained package
`assets/assets_gemma-4-E2B-it_np8_ctx4096_20261022_int16_embedded/`. It uses embedded
NP8 DLA binaries and INT16 Embedding/PLE LUT files, with `modelInputType`,
`embeddingFileType`, `pleFileType`, and `pleInputType` all set to `INT16`. After a device
reboot, all five safe prompts completed (`rc=0`). The exact t0 retry is in
`verify_logs/device_final_int16_t0_retry_20261022/`; t1-t4 are in
`verify_logs/device_final_int16_embedded_bench5_20261022/`. The combined run is an
execution/performance validation only: output quality remains incorrect and was explicitly
excluded from the acceptance criterion.

## Correction: INT16 was only a fallback, not the target artifact

The package used for the stable device benchmark,
`assets_gemma-4-E2B-it_np8_ctx4096_20261022_int16_embedded`, contains
`embedding_int16.bin` and `ple_int16.bin`. This is an execution-stability fallback and
does not satisfy the target requirement of INT4 Embedding/PLE storage. The existing INT4
package is `assets/assets_gemma4_w4a16_embint4_pleint4_group64_np8_20261022/` with
`embedding_int4.bin` (226,492,512 B) and `ple_int4.bin` (1,321,205,856 B), both G4LUTI4
group64. Its YAML declares `embeddingFileType: INT4` and `pleFileType: INT4`; its
`pleInputType: FP16` is not the selected INT4-to-INT16 target interface and must be
regenerated/validated with `pleInputType: INT16`.

The multi-context packaging script was corrected so `LUT_TYPE` defaults to `INT4`,
explicitly selects both `embedding_int4.bin` and `ple_int4.bin`, and emits
`EMBEDDING_FILE_TYPE=INT4`, `PLE_FILE_TYPE=INT4`, `PLE_INPUT_TYPE=INT16`. The old stable
fallback remains available only with `LUT_TYPE=INT16`. No INT4 device acceptance claim is
made until the regenerated INT4/INT16-interface package passes device execution.

## Process lifecycle SIGSEGV comparison (2026-10-23)

On TECNO_CO9m, the same six prompts, INT4/INT4 group64 asset, YAML, max response length (30),
and first-token-with-gen setting were run in two modes. With a fresh `./main` process per prompt,
3/6 runs ended in SIGSEGV (`rc=139`; t1, t3, t4). With one `./main` process reading all six
prompts through `--one-prompt-per-line`, runtime initialized once, reset between prompts, and
completed all six (`rc=0`, no SIGSEGV). The multi-prompt run still produced unusable text for
several prompts; this check measures execution/crash behavior, not output quality.

This is one paired comparison and does not show that runtime reuse fixes the intermittent fault.
An earlier fresh-process suite on the same prompt set had 4/6 SIGSEGV. Treat the process-lifecycle
difference as an observation requiring repeated runs. Logs, prompt input and per-prompt summary:
`verify_logs/process_lifecycle_sigsegv_20261023/`.
