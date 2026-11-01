# Kimi K3

> 开放权重 · 原生多模态 · 2.8T 参数 · 1M 上下文
> 快照日期：2026-11-01 ｜ 一手来源：[MoonshotAI/Kimi-K3](https://github.com/MoonshotAI/Kimi-K3) ｜ [技术博客](https://www.kimi.com/blog/kimi-k3)

---

## 一句话

全球首个开放的 3T 级模型。用 Kimi Delta Attention（KDA）把大部分注意力层换成线性注意力，再用 Attention Residuals 缓解深层信息衰减，从而在 2.8T 总参数下只激活 104B——相对 K2 的整体扩展效率提升约 **2.5×**。

---

## 架构

| 项 | 值 |
| :-- | :-- |
| 结构 | Mixture-of-Experts（MoE） |
| 层数 | 93（1 层 dense） |
| 注意力层构成 | **69 层 KDA + 24 层 Gated MLA** |
| 注意力隐维 | 7168 |
| 注意力头数 | 96 |
| Latent MoE 维度 | 3584 |
| 每专家隐维 | 3072 |
| 专家数 | 896 |
| 每 token 激活专家 | 16 |
| 共享专家 | 2 |
| 词表 | 160K |
| 激活函数 | SiTU-GLU |
| 视觉编码器 | MoonViT-V2（401M） |
| 量化 | MXFP4 权重 / MXFP8 激活（QAT，从 SFT 阶段起） |
| 模态 | 文本、图像 |

两个值得单独说的点：

**KDA 占 3/4。** 93 层里 69 层是线性注意力，只有 24 层保留 gated MLA。这是把长上下文成本压下来的关键——线性注意力层的状态不随序列长度线性增长。

**Stable LatentMoE。** 896 专家选 16，稀疏度比 K2 更高；配合 AttnRes 让极稀疏路由下深层信号仍然可用。

---

## 能力定位

官方定位是"长时程 agentic + 原生多模态"，具体给了三个方向：

- **长时程编码**：在极少人工干预下持续跑长工程会话，导航大型仓库、编排终端工具，覆盖 GPU kernel 优化、编译器开发、vision-in-the-loop 游戏开发、CAD，甚至芯片设计。
- **Agentic 知识工作**：深度研究 + 交互式可视化、widget、dashboard，以及动效与视频剪辑。
- **原生多模态**：文本、图像、视频在同一模型内理解，1M token 上下文。

---

## 评测（官方数据，max effort）

| 类别 | 基准 | Kimi K3 | 对照（同表最高） |
| :-- | :-- | --: | :-- |
| 推理 | GPQA Diamond | 93.5 | 94.1（GPT-5.6 Sol） |
| 推理 | HLE-Full | 43.5 / 56.0 | 53.3 / 63.0（Claude Fable 5） |
| 编码 | DeepSWE | 67.5 | 73.0（GPT-5.6 Sol） |
| 编码 | Terminal-Bench 2.1 | 88.3 | 88.8（GPT-5.6 Sol） |
| 编码 | ProgramBench | 77.8 | 77.6（GPT-5.6 Sol） |
| 编码 | SWE-Marathon | **42.0** | 40.0（Opus 4.8） |
| 编码 | FrontierSWE | 81.2 | 86.6（Claude Fable 5） |
| Agent | BrowseComp | **91.2** | 90.4（GPT-5.6 Sol） |
| Agent | MCPMark-Verified | **94.5** | 92.9（GPT-5.6 Sol） |
| Agent | OSWorld-Verified | 84.8 | 85.0（Claude Fable 5） |
| 视觉 | OmniDocBench | **91.1** | 89.8（Claude Fable 5） |
| 视觉 | Video-MME (w. sub) | **90.0** | 89.5（GPT-5.6 Sol） |

**怎么读这张表**：K3 的强项集中在 agentic 检索（BrowseComp、MCPMark）、超长任务（SWE-Marathon）、文档/视频理解；纯编码基准（DeepSWE、FrontierSWE）上与第一梯队有差距。官方脚注明确说明各家用了不同 Harness，横比要打折扣。

---

## 部署

官方推荐三个引擎：

| 引擎 | 入口 |
| :-- | :-- |
| vLLM | [recipes.vllm.ai/moonshotai/Kimi-K3](https://recipes.vllm.ai/moonshotai/Kimi-K3) |
| SGLang | [docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K3](https://docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K3) |
| TokenSpeed | [lightseek.org/tokenspeed](https://lightseek.org/tokenspeed/recipes/models#kimi-k3) |

API：`platform.kimi.ai`，模型名 `kimi-k3`，同时提供 OpenAI 兼容与 Anthropic 兼容接口。

---

## 接入时的两个坑

### 1. 思考内容必须原样回传

K3 在"保留思考历史"模式下训练。多轮对话与工具调用时，**必须把 API 返回的 assistant message 整体回传**，包括 `reasoning_content` 和 `tool_calls`，不能只传 `content`。否则模型会丢失上一轮的推理上下文。

```python
messages = [
    {"role": "user", "content": "Tell me three random numbers."},
    {
        "role": "assistant",
        "reasoning_content": "I'll start by listing five numbers: 473, 921, 235, 215, 222, ...",
        "content": "473, 921, 235",
    },
    {"role": "user", "content": "What are the other two numbers you have in mind?"},
]
# 关键：assistant 那条要原样放回去，含 reasoning_content
```

### 2. 思考强度是顶层字段

K3 始终开启思考，通过顶层 `reasoning_effort` 控制，取值 `"low"` / `"high"` / `"max"`，默认 `max`。

---

## 许可

代码仓库与模型权重均按 **Kimi K3 License** 发布。商用前请自行阅读许可证原文：<https://huggingface.co/moonshotai/Kimi-K3/blob/main/LICENSE>

---

## 相关

- 技术报告：仓库内 [`k3_tech_report.pdf`](https://github.com/MoonshotAI/Kimi-K3/blob/main/k3_tech_report.pdf)
- 快速上手：<https://platform.kimi.ai/docs/guide/kimi-k3-quickstart>
- Kimi Code CLI：<https://www.kimi.com/code>
