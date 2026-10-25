#!/usr/bin/env pwsh
# One-click update: parent AxmolFighter + every git submodule (including nested Content).
# Safe defaults: fetch, then fast-forward only. Prints which repos moved.
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$originalLocation = Get-Location

function Update-GitRepo {
    param(
        [string]$RepoPath,
        [string]$Label
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[skip] $Label (missing: $RepoPath)" -ForegroundColor Yellow
        return
    }

    $gitMeta = Join-Path $RepoPath ".git"
    if (-not (Test-Path $gitMeta)) {
        Write-Host "[skip] $Label (not a git repo)" -ForegroundColor Yellow
        return
    }

    Push-Location $RepoPath
    try {
        $before = (git rev-parse --short HEAD).Trim()
        $branch = (git rev-parse --abbrev-ref HEAD).Trim()

        Write-Host "=== $Label ===" -ForegroundColor Cyan
        if ($branch -eq "HEAD") {
            Write-Host "  detached HEAD at $before; fetch only (no pull)" -ForegroundColor Yellow
            git fetch --all --prune
            if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $Label" }
            return
        }

        git fetch --all --prune
        if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $Label" }

        git pull --ff-only origin $branch
        if ($LASTEXITCODE -ne 0) {
            throw "git pull --ff-only failed in $Label (local commits or dirty conflicts?). Resolve manually, then re-run."
        }

        $after = (git rev-parse --short HEAD).Trim()
        if ($before -eq $after) {
            Write-Host "  up to date ($after) on $branch"
        }
        else {
            Write-Host "  moved $before -> $after on $branch" -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }
}

try {
    Set-Location $root

    Write-Host "Updating AxmolFighter parent and submodules..." -ForegroundColor Cyan
    Update-GitRepo -RepoPath $root -Label "AxmolFighter (parent)"

    git submodule sync --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule sync failed" }

    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule update --init failed" }

    $submodules = @(
        @{ Path = "AxmolFighter-Client"; Label = "AxmolFighter-Client" },
        @{ Path = "AxmolFighter-UI"; Label = "AxmolFighter-UI" },
        @{ Path = "AxmolFighter-Server"; Label = "AxmolFighter-Server" },
        @{ Path = "AxmolFighter-Tools"; Label = "AxmolFighter-Tools" },
        @{ Path = "AxmolFighter-Config"; Label = "AxmolFighter-Config" },
        @{ Path = "AxmolFighter-Editor"; Label = "AxmolFighter-Editor" },
        @{ Path = "AxmolFighter-Client/Content"; Label = "AxmolFighter-Client/Content" }
    )

    foreach ($sm in $submodules) {
        Update-GitRepo -RepoPath (Join-Path $root $sm.Path) -Label $sm.Label
    }

    Write-Host "=== submodule status ===" -ForegroundColor Cyan
    git submodule status --recursive

    Write-Host "Done." -ForegroundColor Green
}
finally {
    Set-Location $originalLocation
}
