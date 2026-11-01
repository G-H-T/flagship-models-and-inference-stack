# 模型权重

> 权重**不在**本仓库中，只在这里记录来源、体积与获取方式。
> 原因见下方[「为什么权重不能进 git」](#为什么权重不能进-git)。

---

## 权重清单

| 模型 | 权重仓库 | 文件数 | 总大小 | 最大单文件 |
| :-- | :-- | --: | --: | --: |
| DeepSeek-V4.1-Flash-1017 | [HF](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017) · [ModelScope](https://modelscope.cn/models/deepseek-ai/DeepSeek-V4.1-Flash-1017) | 83 | **475.3 GB** | 94.56 GB |
| Kimi K3 | [HF](https://huggingface.co/moonshotai/Kimi-K3) | 待查 | 约 **1.4 TB**（2.8T 参数 × MXFP4 估算） | 待查 |

DeepSeek V4.1 Flash 的实测数字来自 HuggingFace API（`?blobs=true`），2026-11-01 采样：

```
83 files, 475.3 GB
  model-00048-of-00048.safetensors   94.56 GB
  model-00047-of-00048.safetensors   94.56 GB
  model-00017-of-00048.safetensors    6.90 GB
  ...
```

Kimi K3 的权重清单需要登录 HF 才能读取 API（未认证返回 401），上表的 1.4 TB 是按 2.8T 参数、MXFP4 权重推算的**估算值**，不是实测。

---

## 为什么权重不能进 git

四个互相独立的硬约束，任何一个单独就足以否决：

| 约束 | 实际值 | 要求 | 结论 |
| :-- | :-- | :-- | :-- |
| **GitHub 单文件上限** | 最大分片 94.56 GB | 硬上限 100 MB | 超 900 倍 |
| **GitHub 仓库体积** | 至少 475 GB | 建议 < 1 GB，硬上限约 5 GB | 超 2 个数量级 |
| **本机磁盘** | C 盘 318 GB + D 盘 216 GB 可用 | 需 ≥ 475 GB（且要放两份） | 装不下 |
| **git 本身** | 权重是二进制大文件，无法 delta 压缩 | 每次改动都会新增完整副本 | 仓库会迅速不可用 |

即使单个模型能凑进一块磁盘，把 475 GB 二进制放进 git 也意味着：clone 一次要下载 475 GB、每次 `git gc` 都要重新打包、任何一次小改动都会产生新的数百 GB 对象。GitHub 会在推送前就拒绝（>100 MB 的单文件直接拒绝）。

**Git LFS 也救不了**：LFS 单文件上限 2 GB（94.56 GB 仍然超标），且免费额度 1 GB 存储 / 1 GB 月流量。

---

## 本地怎么拿

权重应当留在模型的原始分发渠道，用脚本拉到本机，**不进入版本控制**。仓库里的 [`scripts/download-weights.ps1`](../scripts/download-weights.ps1) 就是干这个的：

```powershell
# 先装客户端
pip install -U huggingface_hub

# 拉 DeepSeek V4.1 Flash（约 475 GB）
pwsh -File scripts/download-weights.ps1 -Model deepseek-v4.1-flash -Dest D:\models

# 拉 Kimi K3
pwsh -File scripts/download-weights.ps1 -Model kimi-k3 -Dest D:\models
```

下载目标默认被 `.gitignore` 忽略（`weights/`、`*.safetensors`、`*.gguf`），不会误提交。

国内网络建议加镜像：

```powershell
$env:HF_ENDPOINT = "https://hf-mirror.com"
```

或改用 ModelScope（V4.1 Flash 有官方镜像）。

---

## 显存 / 磁盘的实际情况

| 模型 | 权重体积 | 推理最低显存（粗略） |
| :-- | --: | :-- |
| DeepSeek-V4.1-Flash-1017 | 475 GB | 需多机多卡（8×H100 级别起步，官方建议 2k 卡规模化部署） |
| Kimi K3 | ~1.4 TB | 需大规模集群 |

如果你只是想**用**这两个模型，走 API 的成本比自建低几个数量级：

- Kimi K3：`platform.kimi.ai`，模型名 `kimi-k3`
- DeepSeek V4.1 Flash：模型名 `deepseek-flash`

---

## 可选：记录校验和

如果确实需要可验证的权重快照，正确做法是**记录 LFS 指针或 SHA256 清单**，而不是存权重本体。HuggingFace 每个仓库都提供 `refs/` 与文件级 SHA，可以只保存几十 KB 的清单，配合 `hf download --dry-run` 校验。

需要的话可以加一个 `weights.lock.json`（记录 83 个分片的 SHA256），体积约几十 KB。
