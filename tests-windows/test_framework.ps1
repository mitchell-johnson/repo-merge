## PowerShell Test Framework for git-merge-repos.ps1
param()

$global:TestsRun = 0
$global:TestsPassed = 0
$global:TestsFailed = 0
$global:CurrentTest = ''

function Start-Test($Name) {
    $global:CurrentTest = $Name
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    $global:TestsRun++
}

function End-Test {
    if ($global:CurrentTestFailed) {
        $global:TestsFailed++
        Write-Host "Test failed: $global:CurrentTest" -ForegroundColor Red
    } else {
        $global:TestsPassed++
        Write-Host "Test passed: $global:CurrentTest" -ForegroundColor Green
    }
    $global:CurrentTestFailed = $false
}

function Assert-Success($Script, $Message="Command should succeed") {
    Invoke-Expression $Script 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] $Message" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $Message" -ForegroundColor Red; $global:CurrentTestFailed = $true }
}
function Assert-Failure($Script, $Message="Command should fail") {
    Invoke-Expression $Script 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  [OK] $Message" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $Message" -ForegroundColor Red; $global:CurrentTestFailed = $true }
}
function Assert-TagExists($Tag,$Msg) {
    git show-ref --verify --quiet "refs/tags/$Tag"
    if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] $Msg" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $Msg" -ForegroundColor Red; $global:CurrentTestFailed=$true }
}
function Assert-TagNotExists($Tag,$Msg) {
    git show-ref --verify --quiet "refs/tags/$Tag"
    if ($LASTEXITCODE -ne 0) { Write-Host "  [OK] $Msg" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $Msg" -ForegroundColor Red; $global:CurrentTestFailed=$true }
}

function Print-Summary {
    Write-Host "`n===== SUMMARY =====" -ForegroundColor Cyan
    Write-Host "Total: $TestsRun  Passed: $TestsPassed  Failed: $TestsFailed"
    if ($TestsFailed -eq 0) { return 0 } else { return 1 }
} 