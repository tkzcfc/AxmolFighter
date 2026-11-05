#!/usr/bin/env pwsh
# One-click update: parent AxmolFighter + every git submodule (including nested Content).
# Keeps each managed repo on its tracking branch (usually main). Never runs an unscoped
# `git submodule update`, which checks out the parent gitlink and leaves a detached HEAD.
# Safe defaults: fetch, then fast-forward only. Prints which repos moved.
$ErrorActionPreference = "Stop"
# Expected non-zero git exits (e.g. merge-base --is-ancestor) must not become terminating errors.
$PSNativeCommandUseErrorActionPreference = $false

$root = $PSScriptRoot
$originalLocation = Get-Location

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs,
        [string]$Label,
        [switch]$AllowFail
    )

    & git @GitArgs
    $code = $LASTEXITCODE
    if (-not $AllowFail -and $code -ne 0) {
        throw ("git {0} failed in {1} (exit {2})" -f ($GitArgs -join ' '), $Label, $code)
    }
    return $code
}

function Get-DefaultBranch {
    param([string]$Label)

    $remoteHead = (git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $remoteHead) {
        return ($remoteHead.Trim() -replace '^origin/', '')
    }

    $code = Invoke-Git -GitArgs @('rev-parse', '--verify', '--quiet', 'refs/remotes/origin/main') -Label $Label -AllowFail
    if ($code -eq 0) {
        return 'main'
    }

    throw "Cannot resolve default branch in $Label (origin/HEAD and origin/main missing). Run git remote set-head origin -a."
}

function Ensure-OnBranch {
    param(
        [string]$Label,
        [string]$Branch
    )

    $current = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($current -eq $Branch) {
        return $Branch
    }

    $detachedCommit = $null
    if ($current -eq 'HEAD') {
        $detachedCommit = (git rev-parse HEAD).Trim()
    }
    else {
        Write-Host "  switching from $current to $Branch" -ForegroundColor Yellow
    }

    $hasLocal = (Invoke-Git -GitArgs @('show-ref', '--verify', '--quiet', "refs/heads/$Branch") -Label $Label -AllowFail) -eq 0
    $hasRemote = (Invoke-Git -GitArgs @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Branch") -Label $Label -AllowFail) -eq 0

    if (-not $hasLocal) {
        if (-not $hasRemote) {
            throw "$Label has no local or origin/$Branch to attach to"
        }

        $startPoint = if ($detachedCommit) { $detachedCommit } else { "origin/$Branch" }
        Invoke-Git -GitArgs @('checkout', '-b', $Branch, $startPoint) -Label $Label | Out-Null
        Invoke-Git -GitArgs @('branch', '--set-upstream-to=origin/' + $Branch, $Branch) -Label $Label | Out-Null
        Write-Host "  created branch $Branch tracking origin/$Branch" -ForegroundColor Green
        return $Branch
    }

    if ($detachedCommit) {
        $detachedBehindBranch = (Invoke-Git -GitArgs @('merge-base', '--is-ancestor', $detachedCommit, "refs/heads/$Branch") -Label $Label -AllowFail) -eq 0
        $branchBehindDetached = (Invoke-Git -GitArgs @('merge-base', '--is-ancestor', "refs/heads/$Branch", $detachedCommit) -Label $Label -AllowFail) -eq 0

        if ($detachedBehindBranch -or ($detachedCommit -eq (git rev-parse "refs/heads/$Branch").Trim())) {
            Invoke-Git -GitArgs @('checkout', $Branch) -Label $Label | Out-Null
        }
        elseif ($branchBehindDetached) {
            # Detached tip is strictly ahead of local branch; move the branch forward first
            # so a later pull --ff-only cannot lose those commits if origin is briefly stale.
            Invoke-Git -GitArgs @('checkout', $Branch) -Label $Label | Out-Null
            Invoke-Git -GitArgs @('merge', '--ff-only', $detachedCommit) -Label $Label | Out-Null
        }
        else {
            throw "$Label has a detached HEAD that diverged from branch $Branch. Resolve it manually, then re-run."
        }

        Write-Host "  attached detached HEAD to branch $Branch" -ForegroundColor Green
        return $Branch
    }

    Invoke-Git -GitArgs @('checkout', $Branch) -Label $Label | Out-Null
    return $Branch
}

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
        Write-Host "=== $Label ===" -ForegroundColor Cyan

        # Never recurse into nested submodules here; this script updates them explicitly.
        Invoke-Git -GitArgs @('-c', 'submodule.recurse=false', 'fetch', '--all', '--prune') -Label $Label | Out-Null

        $branch = Ensure-OnBranch -Label $Label -Branch (Get-DefaultBranch -Label $Label)

        Invoke-Git -GitArgs @('-c', 'submodule.recurse=false', 'pull', '--ff-only', 'origin', $branch) -Label $Label | Out-Null

        $after = (git rev-parse --short HEAD).Trim()
        $headName = (git rev-parse --abbrev-ref HEAD).Trim()
        if ($headName -eq 'HEAD') {
            throw "$Label is still detached after update; refuse to leave a detached HEAD"
        }

        if ($before -eq $after) {
            Write-Host "  up to date ($after) on $headName"
        }
        else {
            Write-Host "  moved $before -> $after on $headName" -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }
}

function Get-MissingSubmodulePaths {
    $paths = @()
    $statusLines = @(git submodule status --recursive)
    foreach ($line in $statusLines) {
        if (-not $line.StartsWith('-')) {
            continue
        }

        # Format: -<sha> <path> [...]
        $parts = $line.TrimStart('-').Trim() -split '\s+', 3
        if ($parts.Count -ge 2) {
            $paths += $parts[1]
        }
    }
    return $paths
}

try {
    Set-Location $root

    Write-Host "Updating AxmolFighter parent and submodules..." -ForegroundColor Cyan
    Update-GitRepo -RepoPath $root -Label "AxmolFighter (parent)"

    Invoke-Git -GitArgs @('submodule', 'sync', '--recursive') -Label "AxmolFighter" | Out-Null

    # Path-scoped init only. A bare `git submodule update --recursive` also rewrites
    # already-checked-out modules to the parent gitlink and detaches HEAD.
    $missing = @(Get-MissingSubmodulePaths)
    if ($missing.Count -gt 0) {
        Write-Host "Initializing $($missing.Count) missing submodule(s): $($missing -join ', ')" -ForegroundColor Cyan
        Invoke-Git -GitArgs (@('submodule', 'update', '--init', '--recursive', '--') + $missing) -Label "AxmolFighter" | Out-Null
    }

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

    $stillDetached = @()
    foreach ($sm in $submodules) {
        $repoPath = Join-Path $root $sm.Path
        if (-not (Test-Path (Join-Path $repoPath '.git'))) {
            continue
        }
        $name = (git -C $repoPath rev-parse --abbrev-ref HEAD).Trim()
        if ($name -eq 'HEAD') {
            $stillDetached += $sm.Label
        }
    }
    if ($stillDetached.Count -gt 0) {
        throw ("Managed submodule(s) still detached: {0}" -f ($stillDetached -join ', '))
    }

    Write-Host "Done." -ForegroundColor Green
}
finally {
    Set-Location $originalLocation
}
