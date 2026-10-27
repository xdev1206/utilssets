# Gemma4 NP8 PROM cut opcode compatibility

## Symptom and cause

NP8 `ncc-tflite` rejected the PROM graph produced by
`cut_tflite_nanov4.sh --opt-prompt-sharedkv` during interpreter setup. FlatBuffer
comparison showed the uncut fix-shape graph used builtin `FULLY_CONNECTED`
version 11 while the cut graph used version 13. Changing that cut graph's
opcode version from 13 to 11 allowed NP8 DLA compilation (PROM DRAM about 1.5G).

## Fix

`fix_scorepath.py --np-compat 8` downgrades the exported FlatBuffer's
`FULLY_CONNECTED` opcode from v13 to v11 immediately after export. The NP8
branch in `8_multictx_np8.sh` passes this option during score-path surgery, so
no separate post-surgery patch is needed.

## Scope

This compatibility change is for NP8 only. Do not apply the v13-to-v11 rewrite
to NP10 builds. The score-path rewrite and opcode compatibility patch do not
change x86 oracle quality; W4A16 quantization results are recorded in the
[W4A16 experiment series](../gemma4/gemma4-w4a16-ptq-experiment-series-20261012-to-20261016.md).
