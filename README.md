# 在 8 GB 笔记本显卡上跑 Qwen3.8-35B-A3B（MTP）— 部署、调优与基准笔记

本仓库记录在**消费级笔记本**（i9-13900H + RTX 4060 Laptop 8GB + 16GB RAM）上，用 **KVMem PolyStrata** 后端运行 **Qwen3.8-35B-A3B**（35B 总参 / 3B 激活，内嵌 MTP 头）的完整过程：

- 模型准备：MTP 头合并（trunk + MTP draft head → 单个 GGUF）
- 部署：256K 上下文、视觉（mmproj）双入口、llama.cpp 备用入口
- 调优：KVMem 参数逐个实测（60+ 组配置），最终稳定配置
- 基准：44 题自建基准、长上下文召回（103K / 253K token）、与同尺寸 35B-A3B 和 DeepSeek-V4.1-Flash 对比
- 接入：OpenAI 兼容 API、DeepSeek Harness、Pi Agent

> 所有内容为**硬件/软件配置、部署步骤、调优数据与基准结果**，仓库内**不包含任何 API Key、Token 或个人信息**。

## 硬件与软件

| 项 | 配置 |
|---|---|
| CPU | Intel Core i9-13900H |
| GPU | NVIDIA GeForce RTX 4060 Laptop GPU，8 GB VRAM |
| RAM | 16 GB |
| OS | Windows 11 (x64) |
| 推理后端 | KVMem v0.19.1（PolyStrata，cu130 版）、llama.cpp b11866 |
| 模型 | Qwen3.8-35B-A3B-Distill-MTP（GGUF，约 15.1 GB，MTP 头已合并） |
| 视觉 | mmproj-Q8_0（CPU 视觉编码） |
| 客户端 | DeepSeek Harness / Pi Agent / 任意 OpenAI 兼容客户端 |

## 目录

| 文档 | 内容 |
|---|---|
| [docs/hardware.md](docs/hardware.md) | 机器配置、显存/内存预算、瓶颈分析 |
| [docs/deploy-kvmem.md](docs/deploy-kvmem.md) | KVMem PolyStrata 部署流程、256K 配置、视觉入口、MTP 合并 |
| [docs/tuning.md](docs/tuning.md) | 参数调优方法与结果（含全部实测参数结论、禁用参数清单） |
| [docs/benchmarks.md](docs/benchmarks.md) | 44 题基准、长上下文、速度、与 DeepSeek-V4.1-Flash 对比 |
| [docs/llamacpp-mtp.md](docs/llamacpp-mtp.md) | llama.cpp + MTP 投机解码备用入口 |
| [docs/integrations.md](docs/integrations.md) | OpenAI 兼容 API 调用、DeepSeek Harness / Pi Agent 接入示例 |
| [scripts/](scripts/) | 启动脚本模板（路径需自行替换） |

## 快速开始

1. 按 [docs/hardware.md](docs/hardware.md) 准备机器（8 GB 显存是硬门槛，16 GB 内存是推荐配置）。
2. 准备模型：Qwen3.8-35B-A3B 主模型 + 对应 MTP 头 GGUF + mmproj（视觉可选），按 [docs/deploy-kvmem.md](docs/deploy-kvmem.md) 合并 MTP 头。
3. 下载 KVMem v0.19.1（Windows x64 + CUDA 13.0）发行包。
4. 修改 `scripts/start-kvmem.ps1` 里的路径/GPU UUID，运行；首次加载约 10–20 秒。
5. 用 OpenAI 兼容客户端访问 `http://127.0.0.1:18200/v1`（API Key 填任意占位值即可，KVMem 不校验）。

## 结论摘要

- **256K 上下文可用**：253,965 token 提示通过，中段验证码召回正确（prefill ≈ 334–372 tok/s，decode ≈ 43–61 tok/s，具体取决于参数与缓存状态）。
- **调优后**（budget 32768 / q8_0 KV / tail-skip 6 / expert-swaps 0）：29.4K 提示总耗时从 70.4 s 降到 **38.8 s（-45%）**；44 题质量不变（**90.9%**）。
- **同尺寸对比**：44 题中，Qwen3.6-35B-A3B 系（TTQ / Hermes）95.5%，DeepSeek-V4.1-Flash 97.7%；本模型 90.9% —— 差距主要在推理题，数学/知识/代码/长文基本打平。
- **速度**：短答解码中位 ≈ 57–64 tok/s；7.5K 预填 ≈ 600–800 tok/s；103K 预填 ≈ 414 tok/s。
- **视觉入口**：OCR 5.9 s、图形计数 11.1 s、表格算术 7.4 s、二轮追问 2.1 s（CPU 视觉，不占显存）。

## 说明

- 这些都是**单机、单用户、单卡**的实测数据，不同硬件/量化/驱动会有差异，仅供参考。
- 仓库文档按"可复现"整理：给出参数、命令、耗时与失败条件；模型文件与 KVMem 发行包请从各自官方渠道获取。
- 本仓库不包含任何密钥；KVMem 本地 API 的 Key 只是占位符。

## License

MIT
