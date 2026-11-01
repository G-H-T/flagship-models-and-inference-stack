# 旗舰模型与推理框架索引

> Kimi K3、DeepSeek V4.1 Flash 等开放权重旗舰模型，以及 DeepSeek 全栈推理框架的一份可核对索引。
>
> **数据快照：2026-11-01** ｜ 星标数取自 GitHub REST API ｜ 规格取自官方模型卡与发布公告

---

## 这个仓库是什么

一份**可验证**的索引，而不是榜单。每个条目都指向一手来源（GitHub 仓库、官方文档、模型权重页），并标注快照时间，避免"看起来对但无法追溯"的信息。

覆盖三层：

| 层 | 内容 | 入口 |
| :-- | :-- | :-- |
| 模型 | Kimi K3、DeepSeek V4.1 Flash 的架构、规格、评测、部署方式 | [models](#一旗舰模型) |
| 推理栈 | DeepSeek 官方开源的**全部**推理相关组件，按六层拆解 | [推理栈](#二deepseek-推理技术栈全景) |
| 源码 | 18 个推理仓库的完整源代码，已在 `vendor/` 内 | [vendor](vendor/) |
| 权重 | 体积、来源与下载方式（**本体不在仓库内**） | [weights](docs/weights.md) |
| 数据 | 机器可读的 `data/*.json` + 星标刷新脚本 | [data](data/) |

---

## 一、旗舰模型

### 1.1 开放权重模型（本次重点）

| 模型 | 机构 | 总参数 | 激活参数 | 上下文 | 模态 | 权重许可 | 仓库 |
| :-- | :-- | --: | --: | --: | :-- | :-- | :-- |
| **Kimi K3** | Moonshot AI | 2.8T | 104B | 1M | 文本 + 图像 | 自定义（Kimi K3 License） | [MoonshotAI/Kimi-K3](https://github.com/MoonshotAI/Kimi-K3) |
| **DeepSeek-V4.1-Flash-1017** | DeepSeek | 552B | 输入 8B / 输出 16B | — | 文本 + 图像 | 见模型卡 | [deepseek-ai](https://github.com/deepseek-ai) |

两份深度笔记：[`docs/kimi-k3.md`](docs/kimi-k3.md) ｜ [`docs/deepseek-v4.1-flash.md`](docs/deepseek-v4.1-flash.md)

**两个模型的核心差异一句话**：Kimi K3 走"极致稀疏 + 超长上下文"路线（896 专家选 16、1M 上下文、KDA 线性注意力占比 3/4）；DeepSeek V4.1 Flash 走"非对称结构 + 极致成本"路线（输入激活仅 8B、KV Cache 压到上一代的 1/4）。

### 1.2 同期对照模型

以下模型仅作为 Kimi K3 官方评测表中的对照组出现，**不代表均为开放权重**，仓库链接仅在有公开代码时给出。

| 模型 | 出现在 | 备注 |
| :-- | :-- | :-- |
| Claude Fable 5 | K3 评测表 | 闭源，Anthropic |
| Claude Opus 4.8 | K3 评测表 | 闭源，Anthropic |
| GPT-5.6 Sol | K3 评测表 | 闭源，OpenAI |
| GPT-5.5 | K3 评测表 | 闭源，OpenAI |
| GLM-5.2 | K3 评测表 | 智谱，评测数据引自其发布博客 |

### 1.3 评测速览（官方数据，非第三方复现）

| 基准 | Kimi K3 (max) | DeepSeek V4.1 Flash 1017 |
| :-- | --: | :-- |
| GPQA Diamond | 93.5 | 见官方图表 |
| DeepSWE | 67.5 | 见官方图表 |
| Terminal-Bench 2.1 | 88.3 | 见官方图表 |
| BrowseComp | 91.2 | 见官方图表 |

> ⚠️ 两家的评测 Harness 不同（K3 主要用 Kimi Code，V4.1 Flash 主要用 mini-swe-v2），**不可直接横比**。V4.1 Flash 的完整数字只以官方图片形式发布，未提供可复制的文本表格，因此此处留空而不做转述。

---

## 二、DeepSeek 推理技术栈全景

### 2.1 背景：为什么是"一堆组件"而不是"一个引擎"

DeepSeek 在 [《The Path to Open-Sourcing the DeepSeek Inference Engine》](https://github.com/deepseek-ai/open-infra-index/tree/main/OpenSourcing_DeepSeek_Inference_Engine) 中说明了取舍：内部引擎是 vLLM 的早期 fork，深度耦合集群管理工具，且团队维护带宽有限。因此**不整包开源**，改为：

1. 把可复用能力抽成独立库（算子、通信、负载均衡……）；
2. 把优化细节以 PR 形式回流 vLLM / SGLang 等上游。

到 2026 年，这条路径的终点产品是 **DeepInfer**——生产级推理引擎本体。所以"DeepSeek 的推理框架"应当理解为**一个分层栈**，而不是单个仓库。

### 2.2 六层结构

```
┌──────────────────────────────────────────────────────────┐
│ ① 引擎/服务层   DeepInfer · deepseek-recipe              │
├──────────────────────────────────────────────────────────┤
│ ② 算子/内核层   FlashMLA · DeepGEMM · DeepGEMM-Ascend    │
│                 TileKernels · DeepSelect · DeepJIT       │
├──────────────────────────────────────────────────────────┤
│ ③ 解码加速层    DeepSpec（投机解码）                      │
├──────────────────────────────────────────────────────────┤
│ ④ 并行/调度层   DeepEP · DeepEP-Ascend · EPLB · LPLB     │
│                 DualPipe · profile-data                  │
├──────────────────────────────────────────────────────────┤
│ ⑤ 存储/数据层   3FS · smallpond                          │
├──────────────────────────────────────────────────────────┤
│ ⑥ 索引/生态层   open-infra-index · awesome-deepseek-*    │
└──────────────────────────────────────────────────────────┘
```

### 2.3 逐项索引

星标数为 2026-11-01 快照。完整机器可读版本见 [`data/deepseek-inference-repos.json`](data/deepseek-inference-repos.json)。

#### ① 引擎 / 服务层

| 项目 | 星标 | 语言 | 许可 | 作用 |
| :-- | --: | :-- | :-- | :-- |
| [DeepInfer](https://github.com/deepseek-ai/DeepInfer) | 24.7k | Python | Apache-2.0 | 支撑 DeepSeek 线上服务的推理引擎，开源版提供离线推理。支持 V4.1-Flash；NVIDIA SM100 / 昇腾 950 |
| [deepseek-recipe](https://github.com/deepseek-ai/deepseek-recipe) | 2.7k | Rust | MIT | 请求格式 ↔ Conversation 转换、prompt 渲染、tokenizer 绑定；把任意推理后端接到多格式 API 服务 |

#### ② 算子 / 内核层

| 项目 | 星标 | 语言 | 许可 | 作用 |
| :-- | --: | :-- | :-- | :-- |
| [FlashMLA](https://github.com/deepseek-ai/FlashMLA) | 13.2k | C++ | MIT | Multi-head Latent Attention 高效内核 |
| [DeepGEMM](https://github.com/deepseek-ai/DeepGEMM) | 9.1k | CUDA | MIT | 干净高效的 GEMM 库（FP8 路线） |
| [DeepGEMM-Ascend](https://github.com/deepseek-ai/DeepGEMM-Ascend) | 624 | C++ | MIT | 昇腾 NPU 版矩阵乘内核库 |
| [TileKernels](https://github.com/deepseek-ai/TileKernels) | 2.0k | Python | MIT | 用 TileLang 写的内核库 |
| [DeepSelect](https://github.com/deepseek-ai/DeepSelect) | 527 | CUDA | MIT | 稀疏注意力（DSA）的 TopK 内核与采样器 |
| [DeepJIT](https://github.com/deepseek-ai/DeepJIT) | 437 | C++ | MIT | xPU 内核 JIT 编译的轻量库 |

#### ③ 解码加速层

| 项目 | 星标 | 语言 | 许可 | 作用 |
| :-- | --: | :-- | :-- | :-- |
| [DeepSpec](https://github.com/deepseek-ai/DeepSpec) | 7.3k | Python | MIT | 投机解码算法的训练与评测全栈代码库 |

#### ④ 并行 / 调度层

| 项目 | 星标 | 语言 | 许可 | 作用 |
| :-- | --: | :-- | :-- | :-- |
| [DeepEP](https://github.com/deepseek-ai/DeepEP) | 10.4k | CUDA | MIT | 专家并行（EP）通信库 |
| [DeepEP-Ascend](https://github.com/deepseek-ai/DeepEP-Ascend) | 283 | C++ | 未标注 | 昇腾 NPU 上的 EP 通信库 |
| [EPLB](https://github.com/deepseek-ai/EPLB) | 1.5k | Python | MIT | Expert Parallelism Load Balancer，冗余专家 + 重排 |
| [LPLB](https://github.com/deepseek-ai/LPLB) | 545 | Python | MIT | 基于线性规划的 EP 负载均衡，早期研究阶段 |
| [DualPipe](https://github.com/deepseek-ai/DualPipe) | 3.0k | Python | MIT | 双向流水线并行，计算-通信重叠（训练侧，推理调度同源） |
| [profile-data](https://github.com/deepseek-ai/profile-data) | 1.2k | — | 未标注 | V3/R1 计算-通信重叠的 profiling 数据与分析 |

#### ⑤ 存储 / 数据层

| 项目 | 星标 | 语言 | 许可 | 作用 |
| :-- | --: | :-- | :-- | :-- |
| [3FS](https://github.com/deepseek-ai/3FS) | 10.4k | C++ | MIT | 面向 AI 训练与推理负载的分布式文件系统 |
| [smallpond](https://github.com/deepseek-ai/smallpond) | 5.0k | Python | MIT | 基于 DuckDB + 3FS 的轻量数据处理框架 |

#### ⑥ 索引 / 生态层

| 项目 | 星标 | 语言 | 许可 | 作用 |
| :-- | --: | :-- | :-- | :-- |
| [open-infra-index](https://github.com/deepseek-ai/open-infra-index) | 8.1k | — | CC0-1.0 | 生产验证过的 AI 基础设施索引，含推理引擎开源路径说明 |
| [awesome-deepseek-integration](https://github.com/deepseek-ai/awesome-deepseek-integration) | 39.7k | — | — | 把 DeepSeek API 接入各类软件 |
| [awesome-deepseek-agent](https://github.com/deepseek-ai/awesome-deepseek-agent) | 6.3k | — | — | Agent 生态集成清单 |

### 2.4 第三方推理引擎

DeepSeek 与 Kimi 都在官方文档里推荐第三方引擎，这两个是当前部署开放权重模型的主流选择：

| 引擎 | 说明 |
| :-- | :-- |
| [vLLM](https://github.com/vllm-project/vllm) | Kimi K3 官方推荐，有专门的 [recipes](https://recipes.vllm.ai/moonshotai/Kimi-K3)；DeepSeek 内部引擎亦源自其早期 fork |
| [SGLang](https://github.com/sgl-project/sglang) | Kimi K3 官方推荐，见 [cookbook](https://docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K3) |
| [TokenSpeed](https://lightseek.org/tokenspeed) | Kimi K3 官方推荐的第三个引擎，见 [recipes](https://lightseek.org/tokenspeed/recipes/models#kimi-k3) |

---

## 三、想跑起来，从哪开始

| 你的情况 | 建议路径 |
| :-- | :-- |
| 只有单机 / 少量卡，想试模型能力 | 走 API：Kimi K3 `platform.kimi.ai`（模型名 `kimi-k3`）；DeepSeek `deepseek-flash` |
| 要多卡自建，NVIDIA | vLLM 或 SGLang 起 Kimi K3；DeepSeek V4.1 Flash 用 DeepInfer（SM100） |
| 要自建，昇腾 | DeepInfer（昇腾 950）+ DeepGEMM-Ascend / DeepEP-Ascend |
| 要做二次开发 / 改内核 | 从 FlashMLA、DeepGEMM、TileKernels 入手 |
| 要压推理成本 | 重点看 DeepSpec（投机解码）、DeepSelect（稀疏注意力 TopK）、EPLB（专家负载均衡） |

---

## 四、完整源码

18 个 DeepSeek 推理相关仓库的**完整源代码**已直接放进 [`vendor/`](vendor/)，不再只是链接。每个都是 `depth=1` 的浅克隆快照，去掉 `.git` 后成为本仓库的普通文件，因此可以离线阅读、全文搜索、直接 diff。

来源 commit 记录在 [`vendor/MANIFEST.json`](vendor/MANIFEST.json)，包含上游 commit SHA、提交时间和文件清单。重新抓取：

```powershell
pwsh -File scripts/vendor-sources.ps1
```

| 目录 | 内容 |
| :-- | :-- |
| [`vendor/DeepInfer`](vendor/DeepInfer) | 生产推理引擎 |
| [`vendor/deepseek-recipe`](vendor/deepseek-recipe) | API 格式适配层 |
| [`vendor/FlashMLA`](vendor/FlashMLA) · [`DeepGEMM`](vendor/DeepGEMM) · [`DeepGEMM-Ascend`](vendor/DeepGEMM-Ascend) · [`TileKernels`](vendor/TileKernels) · [`DeepSelect`](vendor/DeepSelect) · [`DeepJIT`](vendor/DeepJIT) | 算子 / 内核 |
| [`vendor/DeepSpec`](vendor/DeepSpec) | 投机解码 |
| [`vendor/DeepEP`](vendor/DeepEP) · [`DeepEP-Ascend`](vendor/DeepEP-Ascend) · [`EPLB`](vendor/EPLB) · [`LPLB`](vendor/LPLB) · [`DualPipe`](vendor/DualPipe) · [`profile-data`](vendor/profile-data) | 并行 / 调度 |
| [`vendor/3FS`](vendor/3FS) · [`vendor/smallpond`](vendor/smallpond) | 存储 / 数据 |
| [`vendor/open-infra-index`](vendor/open-infra-index) | 基础设施索引文档 |

**关于许可**：各目录保留原始 `LICENSE` 文件，版权归 DeepSeek 及各贡献者所有。本仓库只做搬运，不改变任何授权条款。其中 `DeepEP-Ascend`、`profile-data` 上游未声明许可，引用前请自行判断。

**关于时效**：`vendor/` 是快照，不是跟踪上游最新代码的镜像。要最新代码请直接 clone 上游。

**关于权重**：模型权重**不在**本仓库。DeepSeek V4.1 Flash 是 475 GB / 83 个分片（最大单片 94.56 GB），Kimi K3 约 1.4 TB——超 GitHub 单文件上限 100 MB 近千倍，本机磁盘也放不下。体积明细、失败原因和本地下载脚本见 [`docs/weights.md`](docs/weights.md)。

---

## 五、数据与更新

```
data/
├── models.json                    # 模型规格
└── deepseek-inference-repos.json  # 推理栈仓库清单（含分类、星标、许可）
scripts/
├── update-stars.ps1               # 重新拉取星标并就地更新 JSON
└── vendor-sources.ps1             # 重新抓取全部源码到 vendor/
```

刷新星标：

```powershell
pwsh -File scripts/update-stars.ps1
```

脚本需要 `GITHUB_TOKEN` 环境变量（可选，用于提高 API 速率上限）。

---

## 五、口径与免责

- **星标数**随时间变化，仓库里记录的是标注日期当天的快照，不是实时值。
- **评测数据**全部来自厂商自己的发布材料。不同 Harness、不同工具增强、不同采样参数下的数字**不可直接比较**，本仓库不做二次加工或加权。
- **参数 / 上下文**等规格以官方模型卡为准；标注 `—` 表示官方未给出明确文本值。
- 本项目仅为索引与整理，不包含任何模型权重，不代表 Moonshot AI 或 DeepSeek 官方立场。

---

*最后更新：2026-11-01*
