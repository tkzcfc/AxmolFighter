#!/usr/bin/env pwsh
# One-click push: nested Content first, then each submodule, then parent.
# Pushes existing commits only (no auto-commit, no force). Prints which repos moved.
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$originalLocation = Get-Location

function Push-GitRepo {
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
            Write-Host "  detached HEAD at $before; skip push" -ForegroundColor Yellow
            return
        }

        git fetch --prune origin $branch 2>$null
        if ($LASTEXITCODE -ne 0) {
            git fetch --prune origin
            if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $Label" }
        }

        $remoteRef = "origin/$branch"
        $hasRemote = $true
        git rev-parse --verify $remoteRef 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { $hasRemote = $false }

        if ($hasRemote) {
            $ahead = [int](git rev-list --count "${remoteRef}..HEAD").Trim()
            $behind = [int](git rev-list --count "HEAD..${remoteRef}").Trim()
            if ($behind -gt 0) {
                throw "$Label is behind origin/$branch by $behind commit(s). Pull/rebase first, then re-run."
            }
            if ($ahead -eq 0) {
                Write-Host "  already synced ($before) on $branch"
                return
            }
            Write-Host "  pushing $ahead commit(s) on $branch..."
        }
        else {
            Write-Host "  no origin/$branch yet; pushing new branch..."
        }

        git push -u origin $branch
        if ($LASTEXITCODE -ne 0) { throw "git push failed in $Label" }

        $after = (git rev-parse --short HEAD).Trim()
        Write-Host "  pushed -> $after on $branch" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

try {
    Set-Location $root

    Write-Host "Pushing AxmolFighter nested repos, then parent..." -ForegroundColor Cyan

    # Leaves first so parent/Client gitlinks resolve on the remote.
    $repos = @(
        @{ Path = "AxmolFighter-Client/Content"; Label = "AxmolFighter-Client/Content" },
        @{ Path = "AxmolFighter-Client"; Label = "AxmolFighter-Client" },
        @{ Path = "AxmolFighter-UI"; Label = "AxmolFighter-UI" },
        @{ Path = "AxmolFighter-Server"; Label = "AxmolFighter-Server" },
        @{ Path = "AxmolFighter-Tools"; Label = "AxmolFighter-Tools" },
        @{ Path = "AxmolFighter-Config"; Label = "AxmolFighter-Config" },
        @{ Path = "AxmolFighter-Editor"; Label = "AxmolFighter-Editor" },
        @{ Path = "."; Label = "AxmolFighter (parent)" }
    )

    foreach ($r in $repos) {
        $path = if ($r.Path -eq ".") { $root } else { Join-Path $root $r.Path }
        Push-GitRepo -RepoPath $path -Label $r.Label
    }

    Write-Host "=== submodule status ===" -ForegroundColor Cyan
    git submodule status --recursive

    Write-Host "Done. (This script only pushes existing commits; it does not create commits.)" -ForegroundColor Green
}
finally {
    Set-Location $originalLocation
}
