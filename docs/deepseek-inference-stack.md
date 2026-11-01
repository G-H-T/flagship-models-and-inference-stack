# DeepSeek 推理技术栈全景

> 把 "DeepSeek 的推理框架" 拆成可操作的六层
> 快照日期：2026-11-01

---

## 为什么不是一个仓库

2025 年 3 月，DeepSeek 在开源周之后发了一篇说明：[《The Path to Open-Sourcing the DeepSeek Inference Engine》](https://github.com/deepseek-ai/open-infra-index/tree/main/OpenSourcing_DeepSeek_Inference_Engine)。核心结论是**不整包开源内部引擎**，理由三条：

1. **代码分叉过深**：内部引擎基于一年多前的 vLLM fork，结构相似但为 DeepSeek 模型重度定制，难以泛化到其他场景。
2. **基础设施耦合**：引擎绑定了集群管理工具等内部设施，脱离环境无法部署。
3. **维护带宽不足**：小研究团队，没有余力维护大型开源项目。

替代方案是 **"抽成独立库 + 向上游回流优化"**。所以过去两年看到的是 FlashMLA、DeepGEMM、DeepEP 这样一个个单点库。

到 2026 年，这条路径走到终点：**DeepInfer** 发布，生产引擎本体开源（离线推理部分）。因此完整答案 = DeepInfer + 围绕它的五个支撑层。

---

## 分层地图

```
① 引擎/服务层   DeepInfer · deepseek-recipe
② 算子/内核层   FlashMLA · DeepGEMM · DeepGEMM-Ascend · TileKernels · DeepSelect · DeepJIT
③ 解码加速层    DeepSpec
④ 并行/调度层   DeepEP · DeepEP-Ascend · EPLB · LPLB · DualPipe · profile-data
⑤ 存储/数据层   3FS · smallpond
⑥ 索引/生态层   open-infra-index · awesome-deepseek-*
```

---

## ① 引擎 / 服务层

### DeepInfer — 24.7k ⭐ · Python · Apache-2.0

支撑 DeepSeek 线上大规模服务的推理引擎，2026 年开源，当前提供**离线推理**。

| 维度 | 内容 |
| :-- | :-- |
| 支持模型 | DeepSeek-V4.1-Flash |
| 硬件 | NVIDIA SM100 GPU / 华为昇腾 950 NPU |
| 并行 | Attention DP / 均衡 CP；MoE EP + EPLB |
| 关键特性 | 优化内核、DSpark 投机解码、SWA 有界重放、异步调度、批次不变推理、确定性采样、结构化输出 |
| 依赖内核 | FlashMLA、DeepGEMM、DeepEP、TileKernels、DeepSelect、自研 TileLang 算子 |

**开源版明确缺的三块**（要搭完整在线服务得自己补）：

- KV cache 系统
- VE / Prefill / Decode 分离（引擎侧大部分功能已实现）
- prefill 与 decode 的 DP 副本间负载均衡

这就是"生产引擎开源但没完全开源"的边界所在。

### deepseek-recipe — 2.7k ⭐ · Rust · MIT

不是引擎，是**引擎前面的适配层**。一组 Rust 库 + Python 绑定，负责：

- 把 Messages / Chat Completions / Responses 三种格式的请求统一转成 Conversation
- 把 Conversation 渲染成 DeepSeek 模型能吃的 prompt
- 用附带的 tokenizer 编码成 token ID
- 把模型输出转回对应格式的 response

支持流式、文本、图像、思考模式、客户端工具调用、Chat Completions 的 `prefix` 续写。设计上把**模型推理、工具执行、HTTP 传输**都留给调用方——它只做格式与模板这一层。

---

## ② 算子 / 内核层

这一层是 DeepSeek 最早开源、也最被广泛复用的部分。

| 项目 | 星标 | 语言 | 作用 | 什么时候会直接用到 |
| :-- | --: | :-- | :-- | :-- |
| [FlashMLA](https://github.com/deepseek-ai/FlashMLA) | 13.2k | C++ | MLA 注意力高效内核 | 部署 V3/R1 系列时 attention 的性能关键 |
| [DeepGEMM](https://github.com/deepseek-ai/DeepGEMM) | 9.1k | CUDA | 高效 GEMM 库（FP8） | 自己写推理内核或做量化时 |
| [DeepGEMM-Ascend](https://github.com/deepseek-ai/DeepGEMM-Ascend) | 624 | C++ | 昇腾版 GEMM | 昇腾平台部署 |
| [TileKernels](https://github.com/deepseek-ai/TileKernels) | 2.0k | Python | TileLang 写的内核库 | 想改内核但不想写 CUDA 时 |
| [DeepSelect](https://github.com/deepseek-ai/DeepSelect) | 527 | CUDA | DSA 稀疏注意力的 TopK 内核 + 采样器 | 用 V3.2+ 稀疏注意力时 |
| [DeepJIT](https://github.com/deepseek-ai/DeepJIT) | 437 | C++ | xPU 内核 JIT 编译 | 跨硬件后端做即时编译 |

**演进线索**：FlashMLA（MLA）→ DeepSelect（DSA 稀疏注意力）→ TileKernels（用 TileLang 降低内核编写门槛）→ DeepJIT（跨 xPU 的 JIT）。硬件面从 NVIDIA 单点扩展到昇腾（DeepGEMM-Ascend、DeepEP-Ascend）。

---

## ③ 解码加速层

### DeepSpec — 7.3k ⭐ · Python · MIT

投机解码（speculative decoding）的训练 + 评测全栈代码库。注意它不只是推理端的小技巧，而是包含**训练 draft 模型**的完整链路。

与 DeepInfer 里的 **DSpark + 置信度调度验证** 是同一条技术路线的产物：用 draft token 加速解码，再用置信度估计决定验证多少 token。

---

## ④ 并行 / 调度层

| 项目 | 星标 | 语言 | 作用 |
| :-- | --: | :-- | :-- |
| [DeepEP](https://github.com/deepseek-ai/DeepEP) | 10.4k | CUDA | 专家并行通信库，MoE 推理/训练的通信底座 |
| [DeepEP-Ascend](https://github.com/deepseek-ai/DeepEP-Ascend) | 283 | C++ | 昇腾版 EP 通信 |
| [EPLB](https://github.com/deepseek-ai/EPLB) | 1.5k | Python | 专家并行负载均衡：冗余专家 + 按负载重排 |
| [LPLB](https://github.com/deepseek-ai/LPLB) | 545 | Python | 基于线性规划的 EP 负载均衡，早期研究 |
| [DualPipe](https://github.com/deepseek-ai/DualPipe) | 3.0k | Python | 双向流水线并行，计算-通信重叠 |
| [profile-data](https://github.com/deepseek-ai/profile-data) | 1.2k | — | V3/R1 计算-通信重叠的 profiling 数据 |

**为什么 EP 这么重要**：MoE 模型所有 token 都要经过专家路由，专家分布在不同卡上，通信量直接决定吞吐。DeepEP 解决"怎么传得快"，EPLB 解决"专家怎么摆得匀"。两者缺一不可——只优化通信而专家分布倾斜，热点卡照样是瓶颈。

DualPipe 名义上是训练侧的双向流水线，但计算-通信重叠的调度思路在推理侧同样适用。

---

## ⑤ 存储 / 数据层

| 项目 | 星标 | 语言 | 作用 |
| :-- | --: | :-- | :-- |
| [3FS](https://github.com/deepseek-ai/3FS) | 10.4k | C++ | 面向 AI 训练与推理的分布式文件系统 |
| [smallpond](https://github.com/deepseek-ai/smallpond) | 5.0k | Python | 基于 DuckDB + 3FS 的数据处理框架 |

3FS 与推理的关系容易被忽略：V4.1 Flash 把 SSD 侧的 KV Cache 需求压到 1/8，但**压缩后的缓存仍然要落在高速存储上**——3FS 就是那一层。大规模部署时它是成本模型的一部分，不只是训练基建。

---

## ⑥ 索引 / 生态层

| 项目 | 星标 | 作用 |
| :-- | --: | :-- |
| [open-infra-index](https://github.com/deepseek-ai/open-infra-index) | 8.1k | 生产验证的基础设施索引，含推理引擎开源路径的权威说明 |
| [awesome-deepseek-integration](https://github.com/deepseek-ai/awesome-deepseek-integration) | 39.7k | DeepSeek API 的软件集成清单 |
| [awesome-deepseek-agent](https://github.com/deepseek-ai/awesome-deepseek-agent) | 6.3k | Agent 生态集成清单 |

---

## 怎么组合使用

| 目标 | 组合 |
| :-- | :-- |
| 直接跑 V4.1 Flash（NVIDIA） | DeepInfer，开箱支持 |
| 直接跑 V4.1 Flash（昇腾） | DeepInfer + DeepGEMM-Ascend + DeepEP-Ascend |
| 自己搭 vLLM/SGLang 并提速 | FlashMLA + DeepGEMM + DeepEP + EPLB + DeepSelect |
| 做 API 网关 | deepseek-recipe 做格式适配层，后端接任意引擎 |
| 压 decode 成本 | DeepSpec 训练 draft 模型 + DeepInfer 的 DSpark |
| 超大规模集群 | 上述 + 3FS + smallpond 处理缓存与数据 |

---

## 未覆盖的部分

这些**不在** DeepSeek 开源范围内，但属于完整推理栈的一环：

- 完整在线服务所需的 KV cache 系统
- PD 分离（Prefill/Decode disaggregation）的编排
- DP 副本间的全局负载均衡
- 集群管理与调度（内部工具未开源）

补这些通常要靠 vLLM / SGLang / 自研网关，或者商业推理平台。

---

## 参考

- 开源路径说明：<https://github.com/deepseek-ai/open-infra-index/tree/main/OpenSourcing_DeepSeek_Inference_Engine>
- DeepInfer：<https://github.com/deepseek-ai/DeepInfer>
- 组织全仓库列表：<https://github.com/orgs/deepseek-ai/repositories>
