# DeepSeek V4.1 Flash（1017）

> 非对称架构 · 552B MoE · 原生多模态 · 极致成本
> 快照日期：2026-11-01 ｜ 一手来源：[发布公告](https://api-docs.deepseek.com/zh-cn/news/news260910) ｜ [1017 版本公告](https://api-docs.deepseek.com/zh-cn/news/news261017)

---

## 一句话

DeepSeek 新架构系列里**尺寸最小**的模型，也是当前性价比最激进的一个：552B 总参数，但输入只激活 8B、输出只激活 16B；KV Cache 需求降到上一代的 1/4（HBM）和 1/8（SSD）。

官方措辞是"在基准测试中成功超越了包括 DeepSeek V4 Pro 在内的一众旗舰模型"，并因此计划下线 V4 Pro。

---

## 架构：非对称的 Causal-Encoder-Decoder

核心创新是**输入输出不对称**：

| 项 | 值 |
| :-- | :-- |
| 结构 | MoE + Causal-Encoder-Decoder（非对称） |
| 总参数 | 552B |
| 输入激活 | **8B** |
| 输出激活 | **16B** |
| 模态 | 文本 + 原生视觉理解 |
| 上下文 | 官方未给明确数字（关注后续技术报告） |

设计意图很直白：读入（prefill）便宜、生成（decode）贵，所以让编码侧极度稀疏、解码侧稍微稠密。成本显著低于同尺寸模型，同时预留了向更大参数规模扩展的路径。

### 顺带把 KV Cache 打下来了

这是对 agent 场景最关键的一条——长上下文 agent 任务里，缓存命中费用经常占大头：

| 指标 | 相对上一代 |
| :-- | :-- |
| HBM 需求 | 降至 **1/4** |
| SSD 需求 | 降至 **1/8** |
| 相对初代模型 | KV Cache 累计缩小 **437×** |

---

## 版本演进

| 日期 | 事件 |
| :-- | :-- |
| 2026-04-24 | DeepSeek-V4 预览版发布 |
| 2026-08-13 | DeepSeek-V4-Pro 正式版上线 |
| 2026-08-21 | DeepSeek-V4-Flash-Vision-Exp 上线（多模态 API） |
| 2026-09-10 | **DeepSeek-V4.1-Flash 发布**（552B、非对称结构） |
| 2026-10-17 | **DeepSeek-V4.1-Flash-1017** 发布（当前版本） |

1017 版本的相对提升主要在：基准全面上涨，同时任务运行时间与输出长度缩短——也就是性能-费用帕累托曲线整体右移。官方特别提到针对 **DeepSeek Harness、腾讯 CodeBuddy、WorkBuddy** 做了优化，建议 Harness 升级到 `0.2.1-rc.1` 及以上。

---

## 1017 版本补的三件事

### 1. 从零构建完整项目

通过基于自反馈的 RL 训练，强化了"许愿式编程"——给极少提示词和素材，直接产出完整项目。官方展示的案例：

- 故宫 3D 建模
- 网页版赛车游戏
- 基于 Godot 的《传送门 2》复刻
- Valley of Ages（史前到现代的 3D 动态场景）

### 2. 开放自研搜索 API

DeepSeek 网页端与 API 的搜索一直由自研搜索引擎支撑（索引千亿级网页，日处理数亿次请求）。本次正式开放两个接口：

| 接口 | 价格 |
| :-- | :-- |
| Search | 5 元 / 千次 |
| Fetch | 5 元 / 千次 |

文档：[API 指南 - 网页搜索与抓取](https://api-docs.deepseek.com/zh-cn/guides/search)

> ⚠️ 计费节点：在 DeepSeek Harness / Claude Code / Codex 里通过 Server 端工具调用访问 Search/Fetch，**2026-11-01 00:00（北京时间）起开始按次收费**。此前未计费。

### 3. 权重开源

- HuggingFace：<https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017>
- ModelScope：<https://modelscope.cn/models/deepseek-ai/DeepSeek-V4.1-Flash-1017>

大规模部署（2k 卡 GPU + 存储集群）官方欢迎直接联系。

---

## API

| 项 | 值 |
| :-- | :-- |
| 模型名 | `deepseek-flash` |
| 多模态 | 原生支持 |
| 旧名兼容 | `deepseek-v4-flash`、`deepseek-v4-flash-vision-exp` 临时路由到 V4.1 Flash |
| `deepseek-v4-pro` | 2026-09-14 12:00 起全部路由到 V4.1 Flash，按 V4.1 Flash 单价计费 |
| 定价 | 峰谷定价，闲时为高峰半价 |

---

## 自建部署

官方推理引擎 [DeepInfer](https://github.com/deepseek-ai/DeepInfer) 的默认 checkpoint 就是 `deepseek-ai/DeepSeek-V4.1-Flash-1017`，开箱即可跑离线推理。

| 项 | 要求 |
| :-- | :-- |
| 硬件 | NVIDIA SM100 / 华为昇腾 950 |
| 系统 | Linux |
| Python | 3.12 |
| 编译 | GCC ≥ 13；CUDA 13（NVIDIA）或 CANN 9.2（昇腾） |

```bash
export DEEPINFER_ACCELERATOR=nvidia   # 昇腾用 ascend
./build.sh
python examples/offline_inference.py
```

DeepInfer 侧值得关注的特性：

- **DSpark + 置信度调度验证**：投机解码，`DEEPINFER_ENABLE_MTP_VARLEN=1`
- **SWA 有界重放**：减少 decoder prefill 工作量，V4.1 默认 `DEEPINFER_YOCO_PREFILL_KEEP_TOKENS=140`
- **异步调度**：CPU 批调度与设备执行重叠，默认开启
- **批次不变推理**：`DEEPINFER_BATCH_INVARIANT=1`（仅 NVIDIA），保证不同 batch 组合下结果一致
- **确定性采样**：批次不变 + 关闭 MTP varlen + 固定 `seq_seed`
- **结构化输出**：正则 / JSON Schema / EBNF 约束

> 注意：DeepInfer 开源版是**离线推理**，完整在线服务还缺三块：KV cache 系统、VE/Prefill/Decode 分离、DP 副本间负载均衡。

---

## 相关

- 技术报告：`DeepSeek_V41_Tech_Report.pdf`（在 HF 仓库内）
- 官方推理栈全景：见 [`deepseek-inference-stack.md`](deepseek-inference-stack.md)
