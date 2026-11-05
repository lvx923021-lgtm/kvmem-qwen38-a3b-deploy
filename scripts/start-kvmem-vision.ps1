# KVMem PolyStrata - 视觉 256K 启动脚本模板
# 与文本版共用全部调优参数，只额外启用 CPU 视觉 worker（不占显存）。

$KV      = "D:\AI\KVMem\kvmem-v0.19.1-windows-x64-nvidia-40-unified"
$MODELS  = "E:\models\qwen38-mtp"
$GPU     = "GPU-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$CACHE   = "D:\KVMem-cache"
$PORT    = 18200

$model  = Join-Path $MODELS "Qwen3.8-35B-A3B-Distill-MTP.gguf"
$mmproj = Join-Path $MODELS "mmproj-Q8_0.gguf"

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
  --vision-worker "$KV\workers\polystrata\strata-vision.exe" `
  --mmproj $mmproj --vision-device cpu --vision-tokens 1024 `
  -- --tail-skip 6 --expert-swaps 0
