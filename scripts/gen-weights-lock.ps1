#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate a complete SHA256 lock file for model weight repositories.

.DESCRIPTION
    For every file in a HuggingFace model repo, records path, size and SHA256.
    LFS objects carry their SHA256 in the API response, so multi-hundred-GB
    shards are hashed without downloading them. Small non-LFS files (configs,
    tokenizers, reference code) are downloaded and hashed locally.

    Output: data/weights.lock.json

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/gen-weights-lock.ps1
#>
[CmdletBinding()]
param(
    [string]$Root,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
if (-not $Root) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    if (-not [System.IO.Path]::IsPathRooted($scriptDir)) { $scriptDir = [System.IO.Path]::GetFullPath($scriptDir) }
    $Root = Split-Path -Parent $scriptDir
}
if (-not $OutFile) { $OutFile = Join-Path $Root 'data\weights.lock.json' }

$ProgressPreference = 'SilentlyContinue'
$models = @(
    @{ key = 'deepseek-v4.1-flash-1017'; repo = 'deepseek-ai/DeepSeek-V4.1-Flash-1017' },
    @{ key = 'kimi-k3';                  repo = 'moonshotai/Kimi-K3' }
)

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("whl-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$result = @()
foreach ($m in $models) {
    Write-Host "== $($m.repo)"
    $meta = Invoke-RestMethod -Uri "https://huggingface.co/api/models/$($m.repo)?blobs=true" `
                              -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -TimeoutSec 90
    $rev = $meta.sha
    $files = @()
    $i = 0

    foreach ($f in $meta.siblings) {
        $i++
        $path = $f.rfilename
        $sha  = $null
        $how  = $null

        if ($f.lfs -and $f.lfs.sha256) {
            $sha = $f.lfs.sha256
            $how = 'lfs-metadata'
        }
        else {
            # 非 LFS 文件都很小，直接下载算哈希
            $local = Join-Path $tmp ([guid]::NewGuid().ToString('N'))
            $url = "https://huggingface.co/$($m.repo)/resolve/$rev/$path"
            try {
                Invoke-WebRequest -Uri $url -OutFile $local -UseBasicParsing -TimeoutSec 120
                $sha = (Get-FileHash -Path $local -Algorithm SHA256).Hash.ToLower()
                $how = 'computed'
                Remove-Item $local -Force
            }
            catch {
                Write-Warning "  hash failed: $path - $($_.Exception.Message)"
                $how = 'unavailable'
            }
        }

        $files += [pscustomobject]@{
            path   = $path
            size   = [int64]$f.size
            sha256 = $sha
            source = $how
            blob   = $f.blobId
        }
        if ($i % 20 -eq 0) { Write-Host "   $i/$($meta.siblings.Count)" }
    }

    $bytes = ($files | Measure-Object size -Sum).Sum
    $hashed = ($files | Where-Object { $_.sha256 }).Count
    Write-Host ("   {0} files, {1} GB, hashed {2}/{0}" -f $files.Count, [math]::Round($bytes/1GB,1), $hashed)

    $result += [pscustomobject]@{
        key        = $m.key
        repo       = $m.repo
        url        = "https://huggingface.co/$($m.repo)"
        revision   = $rev
        file_count = $files.Count
        total_bytes= $bytes
        files      = $files
    }
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

$out = [pscustomobject]@{
    generated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    algorithm    = 'sha256'
    note         = '权重本体不在本仓库。此清单用于校验本地下载的权重是否与上游一致。'
    models       = $result
}
$json = $out | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutFile, $json + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host "written: $OutFile"
