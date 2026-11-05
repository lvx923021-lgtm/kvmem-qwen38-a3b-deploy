# KVMem PolyStrata 部署流程

目标：在 8 GB VRAM / 16 GB RAM 上跑 Qwen3.8-35B-A3B（GGUF），**256K 逻辑上下文**，单卡、单用户，OpenAI 兼容 API。

## 1. 准备

1. 从 KVMem 官方发行版获取 `kvmem-v0.19.1-windows-x64-nvidia-40-unified`（Windows x64 + CUDA）。
2. 准备模型：
   - 主模型 GGUF（Qwen3.8-35B-A3B-Distill 系列）
   - MTP 头 GGUF（若主模型未内嵌；合并方法见第 2 节）
   - `mmproj-Q8_0.gguf`（视觉入口需要）
3. 建议目录：
   ```
   <MODELS>\qwen38-mtp\
     Qwen3.8-35B-A3B-Distill-MTP.gguf
     mmproj-Q8_0.gguf
     mtp-....gguf
   <KV_DIR>\kvmem-v0.19.1-windows-x64-nvidia-40-unified\
   ```
4. 缓存目录（SSD KV 层）：
   ```
   D:\KVMem-cache
   ```

## 2. MTP 头合并（trunk + MTP head）

KVMem/llama.cpp 的 MTP 投机解码需要模型**内嵌 MTP 头**（`nextn_predict_layers=1`）。若下载到的是分开的 `mtp-*.gguf`，需要合并：

- 读两个 GGUF 的 header：tensor infos（名字/维度/类型/偏移）、元数据、对齐（32 字节）。
- 目标文件：trunk 的张量数据与 MTP 数据**逐字节拷贝**；只重写张量目录与 offset。
- 校验：
  - 总 tensor 数 = trunk + MTP（本模型 753）；
  - 文件大小 = 头部 + 对齐后数据（本模型 15,135,648,160 字节）；
  - 抽样比对 trunk/MTP 数据块与源文件完全一致；
  - 加载后用 `llama.cpp` 或 KVMem 跑一次短请求确认 `--spec-type draft-mtp` 生效。

参考脚本：本仓库未包含合并脚本（与具体 GGUF 版本相关），但流程如上；关键是**不要重新编码张量数据**，只做目录级合并。

## 3. 启动参数（文本 256K，调优后）

```bat
python "%KV%\tools\polystrata\server.py" ^
  --source "%KV%\backends\polystrata" ^
  --worker "%KV%\workers\polystrata\strata-poly.exe" ^
  --model "<MODELS>\qwen38-mtp\Qwen3.8-35B-A3B-Distill-MTP.gguf" ^
  --gpu "GPU-xxxxxxxx" ^
  --model-alias kvmem-qwen38-mtp --host 127.0.0.1 --port 18200 ^
  --context 262144 --budget 32768 --reserve 1024 --prefill 128 ^
  --host-mib 1024 --sink 64 --recent 128 --kv-type q8_0 ^
  --mtp-drafts 3 --concurrency 1 --vram-reserve-mib 512 ^
  --disk-path "D:\KVMem-cache" --disk-mib 8192 ^
  -- --tail-skip 6 --expert-swaps 0
```

参数含义（完整版见 [tuning.md](tuning.md)）：

| 参数 | 值 | 作用 |
|---|---|---|
| `--context` | 262144 | 逻辑上下文上限 |
| `--budget` | 32768 | KVMem 常驻历史预算；≥常用提示长度可大幅加速预填 |
| `--reserve` | 1024 | 生成本轮新 token 的 KV 空间 |
| `--prefill` | 128 | prompt batch；加大可提速但吃显存，默认 128 最稳 |
| `--host-mib` | 1024 | Host KV payload 硬配额 |
| `--sink` / `--recent` | 64 / 128 | 固定保留的开头/最近 token |
| `--kv-type` | q8_0 | KV 量化，省约 47% KV 显存 |
| `--mtp-drafts` | 3 | 内嵌 MTP 草稿数（1..3） |
| `--vram-reserve-mib` | 512 | 给系统留显存 |
| `--disk-mib` | 8192 | SSD 冷 KV 层配额 |
| worker `--tail-skip` | 6 | 跳过窗口内永远排末位的 CPU 专家，提升解码 |
| worker `--expert-swaps` | 0 | 关闭解码期专家换入，减少与 KV 换入抢带宽 |

## 4. 视觉入口

在文本参数基础上追加：

```bat
  --vision-worker "%KV%\workers\polystrata\strata-vision.exe" ^
  --mmproj "<MODELS>\qwen38-mtp\mmproj-Q8_0.gguf" ^
  --vision-device cpu --vision-tokens 1024
```

说明：
- `--vision-device cpu`：视觉编码器放 CPU，不占 8 GB 显存；代价是每张图约 2–4 秒编码。
- `--vision-tokens 1024`：每图合并 token 上限；512/1024/2048 实测 OCR 质量均可，1024 为平衡值。
- 视觉版与文本版共用 18200 端口，同一时间只能启动一个。
- 视觉版比文本版多约 0.6 GB 内存、启动慢约 3 秒；纯文本速度影响约 5–14%。

## 5. 已验证数据

| 项目 | 结果 |
|---|---|
| 256K 上下文召回 | 253,965 token 提示：中段验证码正确；prefill ≈ 334–372 tok/s；decode ≈ 43–61 tok/s |
| 32K 上下文召回 | 29,354 token：prefill ≈ 640–740 tok/s；总耗时 ≈ 39 s（调优后） |
| 超限保护 | 292K token 请求被拒绝（HTTP 400，提示超过上下文窗口） |
| 视觉 | OCR 5.9 s / 图形计数 11.1 s / 表格算术 7.4 s / 二轮追问 2.1 s，全部正确 |
| 加载时间 | 文本约 8–13 s；视觉约 13–20 s |

## 6. 常见问题

1. **端口被占用**：18200 已有一个 KVMem 实例。启动脚本可加端口检测：已运行则直接打开网页聊天。
2. **CUDA OOM / 加载失败**：减小 `--budget`、`--prefill`、`--vram-reserve-mib`，或改用 `--kv-type q8_0`。
3. **`--fit on` 与显式 `-ngl` 冲突**（llama.cpp）：不要同时给 `-ngl` 和 `--fit on`。
4. **bat 文件必须 CRLF**：LF-only 的 .bat 在 cmd 下会被错误解析。
5. **`--lookup`/`--layer-split`/`--dump-layers`**：KVMem 模式下被包装层强制/拒绝，不要试图覆盖。
6. **长上下文慢**：预算不足时 KVMem 会分段换入；把 `--budget` 提到 ≥ 常用提示长度（本机 32768）可显著改善。
