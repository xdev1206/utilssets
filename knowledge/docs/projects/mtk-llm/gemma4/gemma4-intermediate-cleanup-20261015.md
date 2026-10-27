# Gemma4 中间产物清理记录（2026-10-15）

## 目的

清理 Gemma4 PTQ/fix-shape 历史实验产生的可重建模型图，释放工作区空间；初次清理保留了可复现实验所需的模型、2048 条校准集、配置、日志、对比结果和最终 fixed-shape 结果。2026-10-20 二次清理后，校准数据生成缓存和旧 fixed-shape 中间目录已删除，详见文末记录。

## 清理前检查

执行：

```bash
ps -eo pid,etime,cmd | rg 'mtk_ptq_llm|mtk_fix_llm_shape|mtk_inference_quantized_llm'
df -h .
du -sh work/gemma4_e2b_it/* | sort -h
```

结果：工作区剩余约 48 GB；发现上次中断后仍在运行的 W4A16+embedding-int8+tail-W8A16 PTQ 进程，并生成约 2.7 GB 部分输出。该 PTQ 未完成，因此先终止其 PID `251331/251755/251977`。

## 删除内容

使用已核对的明确目录执行递归删除：

```bash
rm -r -- \
  work/gemma4_e2b_it/calibration_datasets/gemma-4-E2B-it \
  work/gemma4_e2b_it/quantized_models_dynamic \
  work/gemma4_e2b_it/quantized_models_dynamic_2048 \
  work/gemma4_e2b_it/quantized_models_dynamic_embeddings_fp \
  work/gemma4_e2b_it/quantized_models_dynamic_embeddings_fp_fixed \
  work/gemma4_e2b_it/quantized_models_dynamic_fixed \
  work/gemma4_e2b_it/quantized_models_dynamic_fresh500 \
  work/gemma4_e2b_it/quantized_models_dynamic_layer0_only \
  work/gemma4_e2b_it/quantized_models_dynamic_layer0_only_fixed \
  work/gemma4_e2b_it/quantized_models_dynamic_llm_only \
  work/gemma4_e2b_it/quantized_models_tail_dynamic_only \
  work/gemma4_e2b_it/quantized_models_dynamic_embint8_2048_probe \
  work/gemma4_e2b_it/quantized_models_w4a16_2048 \
  work/gemma4_e2b_it/quantized_models_w4a16_embint8_tailw8a16_2048 \
  work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_embint8_2048 \
  work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_embint8_2048_nopad \
  work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_2048 \
  work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_fresh500 \
  work/gemma4_e2b_it/quantized_models/quantized_models_w4a16_2048 \
  work/gemma4_e2b_it/quantized_models_dynamic_embint8_2048
```

删除内容包括旧校准集、历史 dynamic/W4A16 PTQ 图、探针图，以及未完成的新配置 PTQ 图。W4A16 的日志和 x86 对比结果未删除。

## 保留内容

- `work/gemma4_e2b_it/gemma-4-E2B-it/`：模型权重和配置，约 5.9 GB。
- `work/gemma4_e2b_it/calibration_datasets/gemma-4-E2B-it_2048/`：2048 prompts、4096 calibration batches，约 543 GB。
- `work/gemma4_e2b_it/quantized_models/quantized_models_dynamic_embint8_2048_compat/`：dynamic + embedding int8 的最终 fixed-shape 结果，约 6.9 GB。
- `work/gemma4_e2b_it/gemma4_quant_*.json`、`logs/`、`verify_logs/`、项目文档及全局知识库记录。

## 清理结果

```text
清理前可用空间：约 48 GB
清理后可用空间：约 349 GB
释放空间：约 301 GB
```

另发现两个属于其他项目 `/workspace/wenshuai.wang` 的量化推理进程，未终止、未修改。

## 2026-10-20 二次清理

按用户确认，删除旧 PTQ/fix-shape/NP8/MDLA 中间目录、重复资产包和 2048 校准数据生成缓存；保留最终 Embedding pruning + INT8 资产、当前 Embedding/PLE INT4 资产、模型源文件、配置、文档和 `verify_logs/`。本次释放约 500 GB，工作区磁盘占用从约 93% 降至约 62%。

保留的主要资产：`assets/assets_gemma4_hessian_pruned_np8_ctx4096_int8_20261019`、`assets/assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821`、`work/gemma4_e2b_it/quantized_models_w4a16_embint4_tailint4_a16_nohessian_20261019`。

## 日志组织

根目录阶段日志已归档到项目 `logs/`：PTQ 放在 `logs/ptq/gemma4_embint8_pruned_20261016/`，NP8 部署阶段放在 `logs/deploy/np8_hessian_pruned_ctx4096/`，MT6899 编译日志放在 `logs/compile/mt6899/`；根目录不再保留 `*.log`。
