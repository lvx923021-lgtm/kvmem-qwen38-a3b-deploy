# 硬件与系统配置

## 1. 机器配置

| 项 | 值 |
|---|---|
| 机型 | 消费级游戏/创作笔记本（具体型号省略） |
| CPU | Intel Core i9-13900H（6P + 8E，14 核 20 线程） |
| GPU | NVIDIA GeForce RTX 4060 Laptop GPU，**8 GB VRAM**（8188 MiB） |
| 内存 | 16 GB DDR5 |
| 系统盘 | Windows 11 x64 |
| 模型盘 | 独立 SSD（示例 `E:\models`） |
| 缓存盘 | 独立 SSD（示例 `D:\KVMem-cache`） |

该配置的关键点不是 CPU，而是 **8 GB 显存 + 16 GB 内存**：
8 GB 决定了一次能常驻多少专家 + KV；16 GB 决定了长上下文时 host KV 配额与 SSD 换页空间。

## 2. 软件栈

| 组件 | 版本/说明 |
|---|---|
| KVMem | v0.19.1（`kvmem-v0.19.1-windows-x64-nvidia-40-unified`，PolyStrata 后端） |
| 推理 worker | `strata-poly.exe`（KVMem 补丁版 llama.cpp），视觉 worker `strata-vision.exe` |
| CUDA | 13.0 / 13.4 runtime（KVMem 包内自带 `runtime/cuda`） |
| llama.cpp（备用） | b11866（支持 `--spec-type draft-mtp`） |
| 客户端 | DeepSeek Harness、Pi Agent，或任意 OpenAI 兼容客户端 |

## 3. 模型

| 文件 | 说明 |
|---|---|
| `Qwen3.8-35B-A3B-Distill-MTP.APEX-I-MiniPlus-V2.1-Abliterated.gguf` | 主模型（trunk + MTP 头合并后，约 15.1 GB，753 tensors） |
| `mtp-*.gguf` | 单独的 MTP draft 头（合并前使用） |
| `mmproj-Q8_0.gguf` | 视觉投影（mmproj），CPU 视觉时使用 |

架构要点：qwen35moe，41 层（其中 10 个全注意力层），`nextn_predict_layers=1`，内嵌 MTP 头（`blk.40.*` + `blk.40.nextn.*`）。

## 4. 显存/内存预算（实测）

| 项目 | 占用 |
|---|---|
| 模型权重（GPU 常驻部分 + CPU 专家） | 由 KVMem 自动分配；8 GB 卡上约 6.1–6.7 GB VRAM 被权重/缓存占用 |
| KV（f16） | 约 20 KiB/token → 32K 历史 ≈ 640 MiB；q8_0 约 10.6 KiB/token → ≈ 340 MiB |
| 预热后空闲 VRAM | 约 1.2–1.5 GB（留给 prompt batch / 视觉） |
| 空闲 RAM | 约 0.3–2 GB（长文预填时会明显下降，注意换页） |

调优后的默认配置（budget 32768 + q8_0）比默认 f16/budget8192 省约 300 MiB VRAM，用于专家缓存。

## 5. 瓶颈

1. **显存**：8 GB 是主要限制；专家无法全部驻留 GPU，需要 CPU 流式。
2. **内存带宽/容量**：16 GB 在 200K+ 上下文时非常紧，写 SSH/换页会拖慢预填。
3. **CPU**：35B-A3B 的 CPU 专家计算与 Python/视觉编码共用 CPU，后台任务会拉低 token/s。
4. **存储**：SSD KV 层换入换出是长上下文的兜底，CIe/NVMe 速度影响明显。
