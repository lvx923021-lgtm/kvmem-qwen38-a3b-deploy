# llama.cpp + MTP 投机解码 - 256K 备用入口
# 版本要求：b11866+（支持 --spec-type draft-mtp）
# 8 GB 显存下必须用 --fit on，不要手写 -ngl。

$LLAMA   = "D:\AI\llama\llama-server.exe"
$MODELS  = "E:\models\qwen38-mtp"

$model  = Join-Path $MODELS "Qwen3.8-35B-A3B-Distill-MTP.gguf"
$mmproj = Join-Path $MODELS "mmproj-Q8_0.gguf"

& $LLAMA `
  -m $model --mmproj $mmproj `
  --spec-type draft-mtp --fit on `
  -c 262144 -ctk q4_0 -ctv q4_0 -fa on `
  -np 1 --host 127.0.0.1 --port 8080
