# Gemma4 pruned-vocabulary Embedding/PLE INT8 no-Hessian run: float gate blocked (2026-10-27)

## Result

The planned W4A16 + pruned-vocabulary Embedding/PLE INT8 run (`vocab_size=122857`) has not entered PTQ. Its required HF/MTK FP32 gate ended `FAIL` after semantic review, so the project gate blocks calibration/PTQ and later stages. The 20 calibration prompts are archived, but the calibration dataset has not been generated.

## Float verification

- Model: `work/gemma-4-E2B-it_embedding-pruning/`, with its native `chat_template.jinja` and pruned tokenizer.
- Four QA/task prompts used greedy decode (`do_sample=false`, `max_new_tokens=64`). Both sides used the same formatted prompts.
- The first MTK attempt passed the HF `model_type=gemma4` config and was rejected. The successful MTK invocation used a farm config copied from the MTK release `gecko4` config, with `llm.vocab_size` and `llm.vocab_size_per_layer_input` set to 122857; core architecture dimensions matched the HF `text_config`.
- Three answers matched across HF and MTK. The translation answer was marginal (`token_match_ratio=0.6406`, `ROUGE-L=0.7040`) and added commentary contrary to the prompt.
- Both sides returned the same incoherent summary text, including “版集美化了多大新智”; text similarity was perfect for that prompt, but semantic quality failed. Overall automated similarity was `边缘`; overall gate verdict after semantic review was `FAIL`.
- The same summary prompt has a coherent answer in full-vocabulary HF float records from 2026-10-22. This suggests a problem with the pruned checkpoint/tokenizer pair, but does not by itself identify the root cause.

## Records and next investigation

The full outputs, commands, model farm config, 20-prompt calibration file, and SHA-256 inventory are in the [project experiment record](/workspace/xin.xu5/projs/gemma_projs/gemma4/mtk-npu-llm-deploy/work/gemma4_e2b_it/quantization_experiments/20261027_024630_pruned_embple_int8_nohessian/record.md). Investigate the pruned checkpoint/tokenizer mapping and rerun the float gate before any PTQ.
