<#
.SYNOPSIS
    Advanced Git repository merger for Windows/PowerShell.
.DESCRIPTION
    Imports all (or selected) branches/tags from a source repository into the current repo,
    prefixing them with a chosen name.  Supports sub-directory moves, history rewrite via
    git-filter-repo (if available), automatic merge, squash/no-commit options, etc.
    Mirrors functionality of git-merge-repos-advanced.zsh.
.PARAMETER SourceRepo
    Path/URL of the repository to import.
.PARAMETER SourceName
    Prefix used for imported refs.
.EXAMPLE
    ./git-merge-repos.ps1 -MergeTo main https://github.com/org/other.git other
#>
param(
    [Parameter(Mandatory)]
    [string]$SourceRepo,

    [Parameter(Mandatory)]
    [string]$SourceName,

    [string]$Subdirectory,
    [string]$Branch,
    [switch]$SkipTags,
    [switch]$Force,
    [switch]$DryRun,
    [string]$MergeTo,
    [switch]$PreservePaths,
    [switch]$RewriteHistory,
    [switch]$Graft,
    [switch]$SquashMerge,
    [switch]$NoCommit,
    [ValidateSet('recursive','ours','subtree')]
    [string]$Strategy = 'recursive'
)

# AIDEV-NOTE: ps-script - Windows PowerShell port of advanced merger script.

function Write-Color($Color, [string]$Text) {
    Write-Host $Text -ForegroundColor $Color
}

if (!(git rev-parse --git-dir 2>$null)) {
    Write-Color Red 'Error: Not in a git repository'
    exit 1
}

if ($PreservePaths -and $Subdirectory) {
    Write-Color Red 'Error: --PreservePaths cannot be combined with --Subdirectory'
    exit 1
}

$RemoteName = "merge-source-$SourceName-$(Get-Random)"

Write-Color Cyan "Adding remote $RemoteName → $SourceRepo"
if (-not $DryRun) { git remote add $RemoteName $SourceRepo }

Write-Color Cyan 'Fetching branches...'
if (-not $DryRun) { git fetch --no-tags $RemoteName '+refs/heads/*:refs/remotes/'"$RemoteName"'/*' }

# Branch collection
if ($Branch) {
    $Branches = @($Branch)
    if (-not $DryRun) {
        if (-not (git show-ref --verify --quiet "refs/remotes/$RemoteName/$Branch")) {
            Write-Color Red "Error: branch $Branch does not exist in source repo"
            git remote remove $RemoteName | Out-Null
            exit 1
        }
    }
} else {
    if ($DryRun) { $Branches = @() }
    else {
        $Branches = git branch -r | Select-String "^  $RemoteName/" | ForEach-Object { $_.ToString().Trim().Substring($RemoteName.Length+3) } | Where-Object { $_ -ne 'HEAD' }
    }
}

$CreatedBranches = @()
foreach ($b in $Branches) {
    $local = "$SourceName-$b"
    $remoteRef = "$RemoteName/$b"

    if (git show-ref --verify --quiet "refs/heads/$local") {
        if ($Force) {
            Write-Color Yellow "Branch $local exists, deleting (--Force)"
            git branch -D $local | Out-Null
        } else {
            Write-Color Yellow "Branch $local exists, skipping"
            continue
        }
    }

    if ($DryRun) {
        Write-Color Yellow "[DRYRUN] would create branch $local → $remoteRef"
    } else {
        git branch $local $remoteRef
    }
    $CreatedBranches += $local

    if ($Subdirectory) {
        if ($RewriteHistory) {
            # Requires git-filter-repo installed.
            $tmp = New-Item -ItemType Directory -Path ([IO.Path]::GetTempPath()) -Name (New-Guid) -Force
            git clone --single-branch --branch $local . $tmp.FullName | Out-Null
            Push-Location $tmp.FullName
            git filter-repo --to-subdirectory-filter $Subdirectory --force
            Pop-Location
            git fetch $tmp.FullName "$local:$local" --force
            Remove-Item -Recurse -Force $tmp.FullName
        }
        else {
            git filter-branch -f --prune-empty --tree-filter "mkdir -p $Subdirectory; Get-ChildItem -Force -Exclude .git -Recurse | Move-Item -Destination $Subdirectory -Force" -- $local
        }
    }
}

# Tags
if (-not $SkipTags) {
    Write-Color Cyan 'Processing tags...'
    if ($DryRun) { $Tags = @() }
    else {
        $Tags = git ls-remote --tags $RemoteName | ForEach-Object { ($_ -split "\s+")[1] } | ForEach-Object { $_ -replace '^refs/tags/','' } | Where-Object { $_ -notmatch '\^{}$' }
    }
    foreach ($t in $Tags) {
        $newTag = "$SourceName/$t"
        if (git show-ref --tags --verify --quiet "refs/tags/$newTag") {
            if ($Force) { git tag -d $newTag | Out-Null }
            else { Write-Color Yellow "Tag $newTag exists, skipping"; continue }
        }
        if (-not $DryRun) {
            git fetch --no-tags $RemoteName "refs/tags/$t:refs/tags/${RemoteName}_tmp_$t" | Out-Null
            git tag $newTag "${RemoteName}_tmp_$t"
            git tag -d "${RemoteName}_tmp_$t" | Out-Null
        } else {
            Write-Color Yellow "[DRYRUN] would create tag $newTag"
        }
    }
}

# Optional auto-merge
if ($MergeTo -and -not $DryRun) {
    $default = (git symbolic-ref "refs/remotes/$RemoteName/HEAD" 2>$null) -replace "refs/remotes/$RemoteName/",""; if (-not $default) { $default='main' }
    $mergeSrc = "$SourceName-$default"
    git checkout $MergeTo
    Write-Color Cyan "Merging $mergeSrc into $MergeTo"
    $flags = "--strategy=$Strategy --allow-unrelated-histories"
    if ($SquashMerge) { git merge --squash $flags $mergeSrc }
    else {
        $args = @('merge',$flags)
        if ($NoCommit) { $args += '--no-commit' }
        else { $args += @('-m',"Merge branch '$mergeSrc'") }
        $args += $mergeSrc
        git @args
    }
}

Write-Color Cyan 'Cleaning up...'
if (-not $DryRun) { git remote remove $RemoteName }

Write-Color Green 'Merge finished.' 