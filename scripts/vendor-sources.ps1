#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Clone every DeepSeek inference-related repository into vendor/ as plain source.

.DESCRIPTION
    Shallow-clones (depth 1) each repository, strips its .git directory so the
    code becomes ordinary tracked files in this repo, and writes
    vendor/MANIFEST.json recording the exact commit each snapshot came from.

.EXAMPLE
    pwsh -File scripts/vendor-sources.ps1
#>
[CmdletBinding()]
param(
    [string]$Owner  = 'deepseek-ai',
    [string]$Root,
    [string]$Proxy  = 'http://127.0.0.1:7897',
    [int]$Retries   = 4
)

$ErrorActionPreference = 'Stop'
if (-not $Root) {
    # 必须解析成绝对路径：用相对路径调用脚本时 $PSCommandPath 也是相对的，
    # 直接 Split-Path 会把 vendor 建到 scripts/ 下面
    $Root = Split-Path -Parent (Resolve-Path -LiteralPath $PSCommandPath).Path
}
$vendor = Join-Path $Root 'vendor'
New-Item -ItemType Directory -Path $vendor -Force | Out-Null

# 按依赖层次排列，便于阅读
$repos = @(
    # 引擎 / 服务
    'DeepInfer', 'deepseek-recipe',
    # 算子 / 内核
    'FlashMLA', 'DeepGEMM', 'DeepGEMM-Ascend', 'TileKernels', 'DeepSelect', 'DeepJIT',
    # 解码加速
    'DeepSpec',
    # 并行 / 调度
    'DeepEP', 'DeepEP-Ascend', 'EPLB', 'LPLB', 'DualPipe', 'profile-data',
    # 存储 / 数据
    '3FS', 'smallpond',
    # 索引 / 生态
    'open-infra-index'
)

$manifest = @()
foreach ($name in $repos) {
    $dest = Join-Path $vendor $name
    $healthy = $false

    if (Test-Path $dest) {
        Push-Location $dest
        try {
            $null = git rev-parse HEAD 2>$null
            $healthy = ($LASTEXITCODE -eq 0)
        } catch { $healthy = $false }
        Pop-Location
    }

    if (-not $healthy) {
        # GitHub 直连在国内经常抖动，失败后交替用代理重试
        $cloned = $false
        for ($attempt = 1; $attempt -le $Retries -and -not $cloned; $attempt++) {
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            $useProxy = (($attempt % 2) -eq 0) -and $Proxy
            $label = if ($useProxy) { "via $Proxy" } else { 'direct' }
            Write-Host ("cloning {0} (attempt {1}/{2}, {3}) ..." -f $name, $attempt, $Retries, $label)
            if ($useProxy) {
                & git -c "http.proxy=$Proxy" -c "https.proxy=$Proxy" -c core.longpaths=true clone --depth 1 --single-branch --quiet "https://github.com/$Owner/$name.git" $dest 2>&1 | Out-Host
            } else {
                & git -c core.longpaths=true clone --depth 1 --single-branch --quiet "https://github.com/$Owner/$name.git" $dest 2>&1 | Out-Host
            }
            if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $dest '.git'))) {
                $cloned = $true
            } else {
                Start-Sleep -Seconds 3
            }
        }
        if (-not $cloned) { throw "clone failed after $Retries attempts: $name" }
    } else {
        Write-Host "keeping $name (already present)"
    }

    Push-Location $dest
    $sha  = (git rev-parse HEAD)
    $date = (git log -1 --format=%cI)
    $subject = (git log -1 --format=%s)
    Pop-Location

    $files = Get-ChildItem $dest -Recurse -File -Force
    $bytes = ($files | Measure-Object Length -Sum).Sum

    $manifest += [pscustomobject]@{
        repo        = $name
        url         = "https://github.com/$Owner/$name"
        commit      = $sha
        commit_date = $date
        commit_msg  = $subject
        files       = $files.Count
        bytes       = $bytes
    }
    Write-Host ("  {0,-18} {1}  {2} files  {3} MB" -f $name, $sha.Substring(0,8), $files.Count, [math]::Round($bytes/1MB,2))
}

# 去掉嵌套的 .git，让代码成为本仓库的普通文件
Get-ChildItem $vendor -Directory | ForEach-Object {
    $g = Join-Path $_.FullName '.git'
    if (Test-Path $g) { Remove-Item $g -Recurse -Force }
}

$out = [pscustomobject]@{
    generated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    owner        = $Owner
    note         = 'Shallow snapshots (depth=1). Each entry records the upstream commit it was taken from.'
    total_bytes  = ($manifest | Measure-Object bytes -Sum).Sum
    repos        = $manifest
}
$json = $out | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $vendor 'MANIFEST.json'), $json + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host ("done: {0} repos, {1} MB" -f $manifest.Count, [math]::Round($out.total_bytes/1MB,1))
