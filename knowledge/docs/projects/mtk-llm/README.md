# MTK LLM Project Knowledge

This project area covers Gemma4 conversion and quantization, the MTK LLM
runtime, and MediaTek NPU deployment. LiteRT compiler/plugin architecture is
indexed separately under [LiteRT](../litert/README.md).

## Gemma4

- [Gemma4 model and experiment index](gemma4/README.md)

## Runtime

- [Gemma4 Embedding/PLE INT4 storage and runtime design](runtime/gemma4-embedding-int4-runtime-design-20261020.md)
- [Gemma4 G4LUTI4 format and runtime contract](runtime/gemma4-external-lut-g4luti4-int4.md)
- [LiteRT-LM PLE INT4 unpacking](runtime/litert-lm-npu-ple-int4-unpack-analysis.md)

## MediaTek NPU

- [MTK NPU LLM deployment pipeline](mediatek-npu/mtk-npu-llm-deployment-pipeline.md)
- [Gemma4 mixed48 MTK validation (2026-10-02)](mediatek-npu/litert-gemma4-mixed48-mtk-20261002.md)
- [Gemma4 NP8 PROM cut opcode compatibility (2026-10-10)](mediatek-npu/gemma4-np8-prom-cut-opcode-20261010.md)
- [Gemma4 Local RoPE SIGSEGV investigation and fix (2026-10-23)](mediatek-npu/gemma4-local-rope-sigsegv-investigation-20261023.md)
- [Gemma4 embedding/tail INT4 device benchmark (2026-10-20)](mediatek-npu/gemma4-int4-embedding-tail-device-benchmark-20261020.md)
