# Gemma4 `default` activation precision and PLE INT16

## Conclusion

In the Gemma4 PTQ precision JSON, `"default": "sym4W_sym16A"` controls the
default activation precision. It is the configuration input that makes the
PLE path use INT16 activation quantization; it does not mean that the external
TFLite input tensor must be declared as INT16.

The resulting boundary is normally:

```text
per_layer_emb_0 (logical FLOAT32)
    -> QUANTIZE (activation scale)
ple_input.*_quantized (INT16)
```

The device runtime must then use `pleInputType: INT16` so its LUT output buffer
matches the compiled MDLA physical input interface. `default` controls PTQ
graph generation; `pleInputType` controls device-side buffer production. Both
must agree.

## Code path

Verified SDK:

`/workspace/xin.xu5/python_venv/mtk_venv/mtk_gemma4_env/lib/python3.12/site-packages/mtk_llm_sdk`

- `utils/precision_config.py:266-274` reads JSON `default` as
  `self.default_precision`.
- `utils/precision_config.py:914-925` preserves `sym4W_sym16A`; its activation
  half is `sym16A`.
- `utils/precision_config.py:330-335` defaults PLE precision to embedding
  precision when no explicit `ple` field exists. This is the LUT/weight-side
  setting, not the PLE input activation setting.
- For `gemma4_quantized`, `utils/precision_config.py:1661-1681` derives PLE
  hints from `self.default_precision`; `sym4W_sym16A` becomes
  `sym8W_sym16A` hints for `ple_gate_proj` and `ple_proj`.
- `ptq.py:3450-3522` enables converter quantization, installs generated
  precision hints, and supplies calibration ranges.
- `ptq.py:3644-3668` JIT-traces and invokes the converter. The trace input can
  remain FLOAT32; PTQ determines the quantized internal boundary.
- `modeling_x4.py:1805-1809` creates the trace-time PLE input as FLOAT32.
- `shape_fixer.py:3173-3181` only renames the input to `per_layer_emb_0`, and
  `shape_fixer.py:2356-2369` only sets its shape.

## Direct graph verification

The fixed current graph was parsed from:

`work/gemma4_e2b_it/quantized_models_fixed/quantized_models_w4a16_embint8_full_nohessian_20261023_retry/llm/llm_256t4096c/quantized_models_fixed_w4a16_embint8_full_nohessian_20261023_retry_256t4096c_0.tflite`

Observed boundary:

```text
per_layer_emb_0: FLOAT32, shape [1, 256, 35, 256]
consumer: QUANTIZE
output: layers/0/ple_input.1_quantized: INT16
scale: 0.00054931640625
```

The same structure was found in the historical Embedding INT8 + Hessian
graph. Hessian enables converter weight optimization; `sym16A` comes from the
activation half of `default`.

## INT16 versus FP32/FP16

- `default: sym4W_sym16A`: PLE activation path is quantized to INT16 after
  the logical FLOAT32 boundary.
- `default: float`: no INT16 activation quantization is requested; the PLE
  boundary remains floating point unless another transform changes it.
- `pleInputType: INT16`: runtime writes INT16 LUT values into the DLA input
  buffer. It does not create the PTQ `QUANTIZE` node.
- The historical INT8 LUT path sign-extends lookup values into this INT16
  buffer; it does not quantize INT16 values a second time.
- `pleInputType: FP16`: runtime writes FP16 LUT values and is only correct
  when the compiled physical PLE interface is FP16.

The reproducible contract is:

```text
PTQ JSON:  default = sym4W_sym16A
YAML:      pleInputType = INT16
LUT:       INT8/INT4 file decoded to INT16
```

**Core rule:** `default: sym4W_sym16A` is the trigger for the PLE INT16
activation quantization boundary. `pleInputType: INT16` only makes the
runtime/DLA physical buffer match that boundary; it does not create the PTQ
activation quantization node.

## Verification record

- Historical and current graph input `per_layer_emb_0`: FLOAT32.
- Historical and current first PLE quantize output: INT16.
- Current PLE input scale: `0.00054931640625`.
- No SDK source modification is required to create this boundary when PTQ
  already receives `default: sym4W_sym16A`.
