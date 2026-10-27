# Gemma4 embedding/tail INT4 手机 benchmark（2026-10-20）

## 结论

使用 `sym4W_sym16A` 配置生成的 NP8 ctx4096 assets 已在 TECNO CO9m（MT6899）上完成 6 条 prompt 的实际运行。6 条均初始化成功并以 `rc=0` 结束；当前输出存在明显乱码，因此本轮只确认部署链路和性能，不作为算法精度通过结论。

## 量化配置

```json
{
    "llm": {
        "0-34": {
            "q": "sym4W_sym16A",
            "k": "sym4W_sym16A",
            "v": "sym4W_sym16A",
            "o": "sym4W_sym16A",
            "gate": "sym4W_sym16A",
            "up": "sym4W_sym16A",
            "down": "sym4W_sym16A"
        }
    },
    "tail": "sym4W_sym16A",
    "default": "sym4W_sym16A",
    "softmax": "float",
    "res_path": "sym4W_sym16A",
    "embeddings": "sym4W_sym16A",
    "logits": "float",
    "cache": "int8"
}
```

SDK 文件格式说明：该配置的权重为 INT4、激活为 INT16；导出的外部文件名为 `embedding_int16.bin` 和 `ple_int16.bin`，不能仅按外部文件名把 embedding 判定为未量化。

## 产物和命令

- package：`assets/assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821`
- 设备目录：`/data/local/tmp/llm_cmdtool_g4v2/assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821`
- 设备结果：`verify_logs/device_embint4_tailint4_np8_20261020/`

推送命令：

```bash
export ADB_SERVER_SOCKET=tcp:127.0.0.1:15037
export ADB_PORT=15037
DEVBASE=/data/local/tmp/llm_cmdtool_g4v2 \
bash scripts/device/push_cmdtool_gemma4_v2.sh \
  --assets assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821
```

benchmark 命令：

```bash
DEVBASE=/data/local/tmp/llm_cmdtool_g4v2 \
bash scripts/device/run_gemma4_device.sh \
  --assets assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821 \
  --out verify_logs/device_embint4_tailint4_np8_20261020 \
  --prompts verify_logs/screen_baselines/device_prompts_v2 \
  --yaml gemma4_e2b_device_ctx4096.yaml \
  -m 30 --extra "--first-token-with-gen-model"
```

已完成首次 assets 推送后，benchmark 不应再加 `--push-assets`，否则会重复推送约 6.7GB。

## 首次运行故障与修复

首次 benchmark 的 6 条 prompt 都在初始化阶段失败，错误为：

```text
Cannot load file: .../ctx4096_1t4096c_0_shared.dla
```

本地 package 中存在该 GEN DLA，但首次设备目录中缺失。单独补传后恢复：

```bash
adb -s 0826828000012855 push \
  assets/assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821/ctx4096_1t4096c_0_shared.dla \
  /data/local/tmp/llm_cmdtool_g4v2/assets_gemma-4-E2B-it_np8_ctx4096_20261019_220821/
```

补传后的远端文件大小为 `880025799` bytes，随后 6 条均 `rc=0`。

## 性能结果

| prompt | prompt tokens | prefill tok/s | decode tok/s | rc |
|---|---:|---:|---:|---:|
| t0 | 104 | 773.059 | 21.7784 | 0 |
| t1 | 104 | 820.528 | 24.5603 | 0 |
| t2 | 38 | 629.665 | 25.0162 | 0 |
| t3 | 93 | 767.915 | 27.2202 | 0 |
| t4 | 40 | 898.468 | 22.5713 | 0 |
| t5 | 5 | 1657.09 | 25.3231 | 0 |

算术平均：prefill `924.454 tok/s`，decode `24.412 tok/s`。t0 的模型初始化耗时约 `23.2914s`；后续每条均成功完成模型热切换和生成。

## 输出质量

6 条均有返回，但内容明显乱码，例如 t0 返回 ```` ``` theuns ````，因此本轮结果是“设备运行链路 PASS、算法精度 FAIL/未通过”。原始日志和回复保存在项目 `verify_logs/device_embint4_tailint4_np8_20261020/`。

## 五条 prompt 资源测量

2026-10-20 对 t0–t4 逐条重新运行，并每秒采样设备端 `main` 进程的 Android `ps` RSS（KB）和 `%CPU`。RSS 平均值包含该条运行从初始化到结束的全部采样；CPU 超过 100% 表示进程同时使用多个 CPU 核心。

| prompt | 样本数 | RSS 峰值 | RSS 平均 | CPU 峰值 | CPU 平均 |
|---|---:|---:|---:|---:|---:|
| t0 | 12 | 4.754 GiB | 2.010 GiB | 157.0% | 116.442% |
| t1 | 12 | 4.169 GiB | 2.925 GiB | 138.0% | 113.750% |
| t2 | 14 | 4.842 GiB | 2.194 GiB | 152.0% | 113.064% |
| t3 | 9 | 4.498 GiB | 3.153 GiB | 147.0% | 114.533% |
| t4 | 16 | 4.766 GiB | 2.018 GiB | 148.0% | 111.350% |

五条合计 63 个有效采样：RSS 峰值 `4.842 GiB`、RSS 平均 `2.391 GiB`；CPU 峰值 `157.0%`、CPU 平均 `113.613%`。原始采样文件为项目 `verify_logs/device_embint4_tailint4_np8_20261020_mem5_exact/resource_samples.tsv`。

## 验证时间和设备

- 时间：2026-10-20
- serial：`0826828000012855`
- 设备：TECNO CO9m，MT6899，Android 17，arm64
