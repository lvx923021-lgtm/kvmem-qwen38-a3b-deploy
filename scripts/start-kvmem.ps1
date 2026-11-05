# KVMem PolyStrata - 文本 256K 启动脚本模板
# 用法：改下面 5 个变量，然后 PowerShell 运行。
# 已按 8 GB VRAM / 16 GB RAM 调优：budget 32768 / q8_0 KV / tail-skip 6 / expert-swaps 0

$KV      = "D:\AI\KVMem\kvmem-v0.19.1-windows-x64-nvidia-40-unified"   # KVMem 发行包目录
$MODELS  = "E:\models\qwen38-mtp"                                      # 模型目录
$GPU     = "GPU-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"                  # nvidia-smi -L 里的 GPU UUID
$CACHE   = "D:\KVMem-cache"                                            # SSD KV 层目录
$PORT    = 18200

$model = Join-Path $MODELS "Qwen3.8-35B-A3B-Distill-MTP.gguf"

if (-not (Test-Path $CACHE)) { New-Item -ItemType Directory -Path $CACHE | Out-Null }
$env:PATH = "$KV\runtime\cuda;" + $env:PATH

& "$KV\runtime\python\python.exe" "$KV\tools\polystrata\server.py" `
  --source "$KV\backends\polystrata" `
  --worker "$KV\workers\polystrata\strata-poly.exe" `
  --model $model --gpu $GPU `
  --model-alias kvmem-qwen38-mtp --host 127.0.0.1 --port $PORT `
  --context 262144 --budget 32768 --reserve 1024 --prefill 128 `
  --host-mib 1024 --sink 64 --recent 128 --kv-type q8_0 `
  --mtp-drafts 3 --concurrency 1 --vram-reserve-mib 512 `
  --disk-path $CACHE --disk-mib 8192 `
  -- --tail-skip 6 --expert-swaps 0
