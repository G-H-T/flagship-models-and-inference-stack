# 模型权重

> 权重**不在**本仓库中，只在这里记录来源、体积与获取方式。
> 原因见下方[「为什么权重不能进 git」](#为什么权重不能进-git)。

---

## 权重清单

| 模型 | 权重仓库 | 文件数 | 总大小 | 最大单文件 |
| :-- | :-- | --: | --: | --: |
| DeepSeek-V4.1-Flash-1017 | [HF](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017) · [ModelScope](https://modelscope.cn/models/deepseek-ai/DeepSeek-V4.1-Flash-1017) | 83 | **475.3 GB** | 94.56 GB |
| Kimi K3 | [HF](https://huggingface.co/moonshotai/Kimi-K3) | 119 | **1453.8 GB** | 15.82 GB |

两个模型合计 **1929.1 GB（1.88 TB）**。完整校验清单见 [`data/weights.lock.json`](../data/weights.lock.json)：202 个文件、每个都带 SHA256，共 101.9 KB。

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

## 完整校验清单

权重不能进仓库，但**权重的指纹可以**。

[`data/weights.lock.json`](../data/weights.lock.json) 记录了每个文件的路径、字节数和 SHA256：

```json
{
  "generated_at": "2026-11-01T18:49:54+08:00",
  "algorithm": "sha256",
  "models": [
    {
      "key": "deepseek-v4.1-flash-1017",
      "repo": "deepseek-ai/DeepSeek-V4.1-Flash-1017",
      "revision": "1bae0e1088993b9b82de08f59de5be5a34e42170",
      "file_count": 83,
      "total_bytes": 510324508672,
      "files": [
        { "path": "model-00001-of-00048.safetensors", "size": 966367641,
          "sha256": "13bd1210…", "source": "lfs-metadata", "blob": "…" }
      ]
    }
  ]
}
```

| 模型 | 文件 | 覆盖 | 来源 |
| :-- | --: | --: | :-- |
| deepseek-v4.1-flash-1017 | 83 | 83/83 | 49 个取自 LFS 元数据，34 个本地计算 |
| kimi-k3 | 119 | 119/119 | 98 个取自 LFS 元数据，21 个本地计算 |

**关键点**：大分片的 SHA256 直接由 HuggingFace 的 LFS 元数据提供（API 的 `?blobs=true`），**不需要下载 1.88 TB 才能算出来**。只有 config、tokenizer、参考推理代码这些小文件（合计约 20 MB）是下载后本地计算的。

重新生成：

```powershell
powershell -File scripts/gen-weights-lock.ps1
```

拿到权重后校验：

```powershell
$lock = (Get-Content data/weights.lock.json -Raw | ConvertFrom-Json).models[0]
foreach ($f in $lock.files) {
    $actual = (Get-FileHash (Join-Path D:\models\deepseek $f.path) -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $f.sha256) { Write-Warning "MISMATCH: $($f.path)" }
}
```
