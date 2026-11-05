# llama.cpp + MTP 投机解码（备用入口）

当 KVMem 服务不可用或需要更简单的接口时，可以直接用 llama.cpp 加载合并后的 MTP 模型。

## 1. 版本与前提

- llama.cpp **b11866**（支持 `--spec-type draft-mtp`，内嵌 MTP 头投机解码）
- 模型：已合并 MTP 头的 GGUF（`nextn_predict_layers=1`）
- 8 GB 显存下需要 `--fit on`（自动层分配），**不要同时给 `-ngl`**（会 abort/OOM）

## 2. 启动命令（256K，q4_0 KV）

```bat
llama-server.exe ^
  -m "<MODELS>\qwen38-mtp\Qwen3.8-35B-A3B-Distill-MTP.gguf" ^
  --mmproj "<MODELS>\qwen38-mtp\mmproj-Q8_0.gguf" ^
  --spec-type draft-mtp --fit on ^
  -c 262144 -ctk q4_0 -ctv q4_0 -fa on ^
  -np 1 --host 127.0.0.1 --port 8080
```

要点：
- KV 用 q4_0：256K 下 q8_0 KV 占满显存，decode 会掉到约 9 tok/s；q4_0 可到约 21 tok/s。
- 视觉走 `--mmproj`；MTP 走 `--spec-type draft-mtp`（合并模型内置）。
- 与 KVMem 服务不能同时跑（显存冲突）。
- `--fit on` 与 `-ngl` 互斥：不要手写 `-ngl 99`。

## 3. 实测（8 GB 显存，256K 上下文）

| 场景 | 结果 |
|---|---|
| 加载 | `n_ctx=262144`，约 12–13 s |
| 短答 decode | 约 21.6 tok/s（q4_0 KV） |
| 8K 提示 prefill | 约 96 tok/s；decode 约 11.5 tok/s；召回正确 |
| q8_0 KV 对照 | 8K prefill 60.7 tok/s、decode 9.1 tok/s（太慢，已弃用） |

## 4. 限制

- 256K 下 llama.cpp 明显慢于 KVMem（8K 预填约 79 s vs KVMem 约 12 s），只适合小提示/兼容性测试。
- 所有效果依赖具体 GGUF、驱动与 `--fit` 行为；不同版本参数名可能变化。
- 需要 OpenAI 兼容接口时，llama.cpp 的 `/v1/chat/completions` 与 KVMem 相同，可直接替换 base URL。
