#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Download model weights to a local directory (NOT into this repository).

.DESCRIPTION
    Weights are hundreds of gigabytes and cannot live in git. This script pulls
    them from HuggingFace into a destination outside version control.

    Requires: pip install -U huggingface_hub

.EXAMPLE
    pwsh -File scripts/download-weights.ps1 -Model deepseek-v4.1-flash -Dest D:\models

.EXAMPLE
    # 国内镜像
    $env:HF_ENDPOINT = "https://hf-mirror.com"
    pwsh -File scripts/download-weights.ps1 -Model kimi-k3 -Dest D:\models
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('deepseek-v4.1-flash', 'deepseek-v4.1-flash-base', 'kimi-k3')]
    [string]$Model,

    [string]$Dest = (Join-Path $HOME 'models'),

    # 只下载某几个分片，用于先验证链路，例如 -Include "*.json"
    [string]$Include
)

$ErrorActionPreference = 'Stop'

$registry = @{
    'deepseek-v4.1-flash'      = @{ repo = 'deepseek-ai/DeepSeek-V4.1-Flash-1017'; size = '475 GB'; note = '83 个分片，最大单片 94.56 GB' }
    'deepseek-v4.1-flash-base' = @{ repo = 'deepseek-ai/DeepSeek-V4.1-Flash';      size = '约 475 GB'; note = '9 月发布版，1017 的前代' }
    'kimi-k3'                  = @{ repo = 'moonshotai/Kimi-K3';                   size = '约 1.4 TB'; note = '2.8T 参数 MXFP4' }
}

$target = $registry[$Model]
if (-not $target) { throw "unknown model: $Model" }

Write-Host ""
Write-Host "模型:   $Model"
Write-Host "仓库:   $target.repo"
Write-Host "体积:   $($target.size)  ($($target.note))"
Write-Host "目标:   $Dest"
Write-Host ""

# 磁盘余量检查
if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
$drive = (Get-Item $Dest).PSDrive
$freeGb = [math]::Round($drive.Free / 1GB, 1)
Write-Host "磁盘可用: $freeGb GB"
if ($Model -eq 'deepseek-v4.1-flash' -and $freeGb -lt 500) {
    Write-Warning "可用空间 $freeGb GB 可能不足以容纳 475 GB 权重。继续会在中途失败。"
}

# 确认客户端可用
$cli = Get-Command hf -ErrorAction SilentlyContinue
$legacy = Get-Command huggingface-cli -ErrorAction SilentlyContinue
if (-not $cli -and -not $legacy) {
    throw "未找到 hf / huggingface-cli。请先执行: pip install -U huggingface_hub"
}

$exe = if ($cli) { 'hf' } else { 'huggingface-cli' }
Write-Host "客户端: $exe"
Write-Host ""

$args = @('download', $target.repo, '--local-dir', (Join-Path $Dest $Model))
if ($Include) {
    $args += '--include'
    $args += $Include
}

Write-Host "执行: $exe $($args -join ' ')"
Write-Host ""
& $exe @args

if ($LASTEXITCODE -ne 0) { throw "下载失败 (exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "完成。权重位于: $(Join-Path $Dest $Model)"
Write-Host "注意: 该目录不应进入 git（.gitignore 已排除 weights/、*.safetensors、*.gguf）"
