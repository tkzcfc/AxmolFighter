#!/usr/bin/env pwsh
# One-click update: parent AxmolFighter + every git submodule (including nested Content).
# Submodules are kept on a local branch: a detached HEAD is re-attached before pulling,
# so the working copy does not end up detached after every update.
# Safe defaults: fetch, then fast-forward only. Prints which repos moved.
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$originalLocation = Get-Location

function Assert-GitSuccess {
    param(
        [string]$Action,
        [string]$Label
    )

    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed in $Label"
    }
}

function Get-DefaultBranch {
    # origin/HEAD is the branch `git submodule update` would track for a submodule.
    $remoteHead = (git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $remoteHead) {
        return ($remoteHead.Trim() -replace '^origin/', '')
    }

    return 'main'
}

function Attach-DetachedHead {
    param(
        [string]$Label,
        [string]$Branch,
        [string]$DetachedCommit
    )

    git show-ref --verify --quiet "refs/heads/$Branch"
    $hasLocalBranch = ($LASTEXITCODE -eq 0)

    if (-not $hasLocalBranch) {
        git checkout -b $Branch $DetachedCommit
        Assert-GitSuccess -Action "git checkout -b $Branch" -Label $Label

        git rev-parse --verify --quiet "refs/remotes/origin/$Branch" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            git branch --set-upstream-to="origin/$Branch" $Branch
            Assert-GitSuccess -Action "git branch --set-upstream-to=origin/$Branch" -Label $Label
        }

        Write-Host "  attached detached HEAD to new branch $Branch" -ForegroundColor Green
        return
    }

    git merge-base --is-ancestor $DetachedCommit "refs/heads/$Branch"
    $detachedBehindBranch = ($LASTEXITCODE -eq 0)

    git merge-base --is-ancestor "refs/heads/$Branch" $DetachedCommit
    $branchBehindDetached = ($LASTEXITCODE -eq 0)

    if ($detachedBehindBranch) {
        # The branch already contains the checked-out commit; just move onto it.
        git checkout $Branch
        Assert-GitSuccess -Action "git checkout $Branch" -Label $Label
    }
    elseif ($branchBehindDetached) {
        # Keep detached commits by fast-forwarding the branch onto them.
        git checkout $Branch
        Assert-GitSuccess -Action "git checkout $Branch" -Label $Label

        git merge --ff-only $DetachedCommit
        Assert-GitSuccess -Action "git merge --ff-only $DetachedCommit" -Label $Label
    }
    else {
        throw "$Label has a detached HEAD that diverged from branch $Branch. Resolve it manually, then re-run."
    }

    Write-Host "  attached detached HEAD to branch $Branch" -ForegroundColor Green
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

        git fetch --all --prune
        Assert-GitSuccess -Action "git fetch" -Label $Label

        $branch = (git rev-parse --abbrev-ref HEAD).Trim()
        if ($branch -eq "HEAD") {
            $detachedCommit = (git rev-parse HEAD).Trim()
            $branch = Get-DefaultBranch

            git rev-parse --verify --quiet "refs/remotes/origin/$branch" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  detached HEAD at $before; origin/$branch not found, skipping pull" -ForegroundColor Yellow
                return
            }

            Attach-DetachedHead -Label $Label -Branch $branch -DetachedCommit $detachedCommit
        }

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
    Assert-GitSuccess -Action "git submodule sync" -Label "AxmolFighter"

    # Only run `submodule update` when something is genuinely missing: it checks out the
    # gitlink commit and detaches HEAD, which would drop local commits and branch state.
    $missingSubmodules = @(git submodule status --recursive | Where-Object { $_.StartsWith('-') })
    if ($missingSubmodules.Count -gt 0) {
        Write-Host "Initializing $($missingSubmodules.Count) missing submodule(s)..." -ForegroundColor Cyan
        git submodule update --init --recursive
        Assert-GitSuccess -Action "git submodule update --init" -Label "AxmolFighter"
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

    Write-Host "Done." -ForegroundColor Green
}
finally {
    Set-Location $originalLocation
}
