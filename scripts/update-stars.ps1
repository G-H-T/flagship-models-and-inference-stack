#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Refresh star counts in data/deepseek-inference-repos.json from the GitHub API.

.DESCRIPTION
    Reads the repo list, queries each repository, updates the "stars" field in place,
    and rewrites the JSON file with a fresh snapshot_date.

    Set GITHUB_TOKEN to raise the API rate limit (60 req/h unauthenticated).

.EXAMPLE
    pwsh -File scripts/update-stars.ps1
#>
[CmdletBinding()]
param(
    [string]$DataFile = (Join-Path $PSScriptRoot '..' 'data' 'deepseek-inference-repos.json')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DataFile)) {
    throw "Data file not found: $DataFile"
}

$headers = @{
    'User-Agent' = 'flagship-models-and-inference-stack'
    'Accept'     = 'application/vnd.github+json'
}
if ($env:GITHUB_TOKEN) {
    $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
}

$json = Get-Content -Path $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json
$updated = 0
$failed = @()

foreach ($layer in $json.layers) {
    foreach ($repo in $layer.repos) {
        try {
            $api = "https://api.github.com/repos/$($repo.url -replace '^https://github.com/', '')"
            $info = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 30
            if ($repo.stars -ne $info.stargazers_count) {
                Write-Host ("  {0}: {1} -> {2}" -f $repo.name, $repo.stars, $info.stargazers_count)
            }
            $repo.stars = $info.stargazers_count
            if ($info.language) { $repo.language = $info.language }
            $updated++
            Start-Sleep -Milliseconds 150   # be polite to the API
        }
        catch {
            Write-Warning "failed: $($repo.name) — $($_.Exception.Message)"
            $failed += $repo.name
        }
    }
}

$json.snapshot_date = (Get-Date).ToString('yyyy-MM-dd')

$out = $json | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($DataFile, $out + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Updated $updated repo(s). Snapshot date: $($json.snapshot_date)"
if ($failed.Count -gt 0) {
    Write-Host "Failed: $($failed -join ', ')"
    exit 1
}
