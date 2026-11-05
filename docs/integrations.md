# 客户端接入（OpenAI 兼容）

KVMem、llama.cpp 都提供 OpenAI 兼容接口，密钥只是占位值（KVMem 不校验，llama.cpp 无鉴权）。

## 1. 本地 KVMem

| 项 | 值 |
|---|---|
| Base URL | `http://127.0.0.1:18200/v1` |
| API Key | 任意（示例 `local-key`） |
| 模型 ID | `kvmem-qwen38-mtp` |
| 上下文 | 262144 |
| 网页聊天 | `http://127.0.0.1:18200/` |

### curl

```bash
curl http://127.0.0.1:18200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer local-key" \
  -d '{"model":"kvmem-qwen38-mtp","messages":[{"role":"user","content":"你好"}],"max_tokens":64}'
```

### PowerShell

```powershell
$body = @{
  model = 'kvmem-qwen38-mtp'
  messages = @(@{ role = 'user'; content = '你好' })
  max_tokens = 64
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri 'http://127.0.0.1:18200/v1/chat/completions' `
  -Method Post -Body $body -ContentType 'application/json' `
  -Headers @{ Authorization = 'Bearer local-key' }
```

### 关闭思考（快答）

```json
"chat_template_kwargs": { "enable_thinking": false }
```

### 图片输入（视觉入口）

```json
{
  "model": "kvmem-qwen38-mtp",
  "messages": [{
    "role": "user",
    "content": [
      {"type": "text", "text": "图片里是什么？"},
      {"type": "image_url", "image_url": {"url": "data:image/png;base64,<BASE64>"}}
    ]
  }]
}
```

## 2. DeepSeek Harness 配置（示例，Key 用占位符）

```yaml
providers:
  kvmem:
    displayName: KVMem Qwen3.8 35B (local)
    api: openai-completions
    baseURL: http://127.0.0.1:18200/v1
    headers:
      Authorization: Bearer local-key
    models:
      - id: kvmem-qwen38-mtp
        name: Qwen3.8-35B-A3B (KVMem 256K)
        contextWindow: 262144
        maxTokens: 4096
        input: [text]
```

并把默认模型指向 `kvmem/kvmem-qwen38-mtp`。

## 3. Pi Agent / 通用客户端

`models.json`（Pi 的 provider 配置）示例：

```json
{
  "providers": {
    "KVMem": {
      "api": "openai-completions",
      "baseUrl": "http://127.0.0.1:18200/v1",
      "apiKey": "local-key",
      "models": [{
        "id": "kvmem-qwen38-mtp",
        "name": "Qwen3.8-35B-A3B (KVMem 256K)",
        "reasoning": true,
        "input": ["text"],
        "contextWindow": 262144,
        "maxTokens": 8192
      }]
    },
    "KVMem-Vision": {
      "api": "openai-completions",
      "baseUrl": "http://127.0.0.1:18200/v1",
      "apiKey": "local-key",
      "models": [{
        "id": "kvmem-qwen38-mtp",
        "name": "Qwen3.8-35B-A3B (KVMem 256K · 视觉)",
        "reasoning": true,
        "input": ["text", "image"],
        "contextWindow": 262144
      }]
    }
  }
}
```

命令行用法（以 Pi 为例）：

```
pi -p --provider KVMem --model kvmem-qwen38-mtp "问题"
pi -p --provider KVMem-Vision --model kvmem-qwen38-mtp "@图片路径" "图片里是什么？"
```

## 4. llama.cpp 备用接口

- Base URL：`http://127.0.0.1:8080/v1`
- API Key：不需要
- 模型名：任意（llama.cpp 忽略）

## 5. 注意

- 视觉入口需要先启动视觉版服务；同一时间只有一个服务占用 18200。
- 长上下文客户端应把 contextWindow 设为 262144，但实际可用上限取决于服务端 `--context` 与显存。
- 本仓库示例中的 Key 均为占位符 `local-key`，请勿使用真实密钥提交到仓库。
