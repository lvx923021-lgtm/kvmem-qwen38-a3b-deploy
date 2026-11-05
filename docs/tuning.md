# 参数调优：方法、结果与最终配置

## 1. 方法

1. **源码研读**：KVMem v0.19.1 源码（`kvmem/` 核心、`backends/patches/polystrata-*.patch`）+ 发行包 `server.py`、worker `--help`，整理出完整参数手册（前端 35 项、worker 50+ 项、环境变量 22 组，含默认值与实现位置）。
2. **快速筛选**：40 组配置 × （200 token 短答 + 7.5K 文档），测 prefill/decode/TTFT/加载/显存。
3. **深度筛选**：15 组配置 × 29.4K 文档（含中段验证码召回、二次追问）。
4. **决赛**：3 组最优候选，各重复两轮。
5. **最终验证**：117,965 token、253,965 token 召回 + 44 题质量基准。
6. **逐参数补测**：对剩余参数（stage-read、skip-weight、cache-bias、cpu-share、expert-profile、no-gpu-experts、kv-whole、thinking 系列、concurrency、环境变量、视觉线程/token 数等）逐项实测。

统一条件：`concurrency=1`、`vram-reserve 512`、无视觉、思考关闭（除思考专项测试）；温度 0.3；单次请求串行。

## 2. 关键结论

### 2.1 有效改进（已采用）

| 参数 | 旧值 | 新值 | 效果 |
|---|---|---|---|
| `--budget` | 8192 | **32768** | 29.4K 提示 prefill 418→741 tok/s，总耗时 70.4→38.8 s（-45%）；原理：B ≥ 提示长度时 KV 常驻、免流式重算 |
| `--kv-type` | f16 | **q8_0** | KV 20→10.6 KiB/token，省约 300 MiB 显存给专家缓存；44 题质量 90.9% 不变 |
| worker `--expert-swaps` | 64（默认） | **0** | 避免与 KV 换入抢带宽；29.4K 第二轮 47–57 s→39–40 s |
| worker `--tail-skip` | 0 | **6** | 29.4K decode 26.8→45.4 tok/s；质量无下降（44 题不变） |

其他保持默认：reserve 1024、prefill 128、host-mib 1024、sink 64、recent 128、MTP drafts 3、vram-reserve 512、disk 8192、block 32。

### 2.2 明确不要用（实测变差）

| 参数 | 值 | 结果 |
|---|---|---|
| `--query-scorer` | meanq-cosine | 灾难：7.5K prefill 123 tok/s（会触发 LRFU/自动 max） |
| `--stage-mib` | 4096 | 7.5K prefill 111 tok/s |
| `--stage-ahead` | 512 | 7.5K prefill 114 tok/s |
| `--cache-bias` | 0.1 | 7.5K prefill 147 tok/s |
| `--sink` | 12288 | 7.5K prefill 273 tok/s |
| `--budget` | 4096 | 7.5K prefill 326 tok/s（B < 提示长度） |
| `--no-gpu-experts` | 开 | 7.5K prefill 58 tok/s |
| `--kv-whole` | 开 | 可加载，但比默认慢（639 vs 737 tok/s） |
| `--expert-swaps` | 128 | 启动失败（只接受 0..64） |
| `--prefill` | 512 | 单轮可到 1062 tok/s，但第二轮退化到 87 s（显存压力不稳定） |
| `--concurrency` | 2 | 会关闭 MTP（draft≈0），单用户无收益 |
| `STRATA_FATTN` | 0 | 7.5K prefill 204 tok/s（必须保持 1） |
| `--backend` | hip | 打印 KVMEM_EXPERIMENTAL，未验收 |

### 2.3 逐参数补测结论（摘要）

- **worker**：`stage-read-mib` 64/128、`skip-weight` 0.02/0.05、`cpu-share` 0.15/0.3、`any-node`、`draft-vocab 32768`、`expert-profile` 均在噪声内或无收益；`threads` 10/14/18 中默认 14 最优。
- **思考相关**：`--thinking-mode off` 可完全直答（15 token）；`--thinking-budget 512` 生效；`--thinking-mode on` + `--reasoning-effort none` 组合被拒。
- **前端**：`--tokenizer` 显式路径、`--chat-template-file`、`--log`、`--model-alias abc`、`--port 18201`、`--disk-path E:` 均正常；`--host 0.0.0.0` 无 `STRATA_API_KEY` 会被正确拒绝。
- **lrfu**：`--lrfu` / `--lrfu-lambda 0.25` / `--lrfu-top-frac 0.5` 均可用，无收益，保持关闭。
- **视觉**：`--vision-tokens` 512/1024/2048、`--vision-threads` 8/12 对 OCR（6.4–6.7 s）无显著差异，保持 1024/默认。
- **history**：`--no-history-reuse` 需配合 `--retained-sessions 1`；sessions 2/4 在单请求下无差异。

## 3. 最终配置

```text
server.py --context 262144 --budget 32768 --reserve 1024 --prefill 128
          --host-mib 1024 --sink 64 --recent 128 --kv-type q8_0
          --mtp-drafts 3 --concurrency 1 --vram-reserve-mib 512
          --disk-path D:\KVMem-cache --disk-mib 8192
          -- --tail-skip 6 --expert-swaps 0
```

## 4. 取舍

- 新配置在 29K/103K 提示上明显更快，但 **253K 满上下文**的 prefill 比旧配置（约 372 tok/s）低约 10%（334 tok/s）。
- 如果更看重 250K 级超长提示的绝对预填速度，可把 `--kv-type` 换回 f16、`--budget` 回 8192（代价是 29K 场景慢约 40%）。
- q8_0 KV 在本机 44 题质量上与 f16 持平，但不同任务/模型可能有差异，建议自测。

## 5. 复现

- 用 `scripts/start-kvmem.ps1` 起服务（参数已在脚本中）。
- 预填/解码测速：对同一提示连续请求两次，读取 OpenAI 响应里的 `timings`（KVMem 返回 `prompt_per_second` / `predicted_per_second`）。
- 长文召回：构造约 2.6K–254K token 文档，中段埋唯一验证码，检查回答是否精确复述。
- 44 题质量：见 [benchmarks.md](benchmarks.md)。
