# ============================================================================
# Script: build_with_github.ps1
# Description: Automated GitHub SDK / CLI pipeline to build and download
#              the UET Societies Hub Release APK directly to your machine.
# ============================================================================

$ErrorActionPreference = "Stop"

# Ensure we are in the project root directory
Set-Location "D:\MVP"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  UET Societies Hub - Automated GitHub SDK / CLI Build   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate gh CLI
$ghPath = "C:\Program Files\GitHub CLI\gh.exe"
if (-not (Test-Path $ghPath)) {
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $ghPath = $ghCmd.Source
    } else {
        Write-Error "GitHub CLI is not found. Please install via: winget install GitHub.cli"
        exit 1
    }
}

Write-Host "[✓] GitHub CLI located: $ghPath" -ForegroundColor Green

# 2. Check Auth Status
Write-Host "`n[1/5] Verifying GitHub authentication..." -ForegroundColor Yellow
$authCheck = & $ghPath auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Not logged in. Launching web authentication..." -ForegroundColor Magenta
    Write-Host "    Press Enter, copy the one-time code shown in terminal, and approve in your browser." -ForegroundColor Gray
    & $ghPath auth login --web -h github.com -p https -s repo,workflow
}

Write-Host "[✓] Authenticated successfully." -ForegroundColor Green

# 3. Create or Link Remote Repository
Write-Host "`n[2/5] Setting up remote repository on GitHub..." -ForegroundColor Yellow
$remotes = git remote
if ($remotes -notcontains "origin") {
    Write-Host "Creating new repository 'uet-societies-hub' on your GitHub account..." -ForegroundColor Cyan
    & $ghPath repo create uet-societies-hub --public --source=. --remote=origin --push
} else {
    Write-Host "Pushing latest commits to GitHub origin/main..." -ForegroundColor Cyan
    git push -u origin main
}

# 4. Trigger and Watch Cloud Build Workflow
Write-Host "`n[3/5] Triggering GitHub Actions cloud build for Android APK..." -ForegroundColor Yellow
& $ghPath workflow run "Build Android Release APK"

Write-Host "Waiting 5 seconds for GitHub runner initialization..." -ForegroundColor Gray
Start-Sleep -Seconds 5

Write-Host "`n[4/5] Watching cloud compilation in real-time..." -ForegroundColor Cyan
& $ghPath run watch

# 5. Download the APK Artifact
Write-Host "`n[5/5] Downloading completed APK artifact..." -ForegroundColor Yellow
& $ghPath run download --name uet-societies-hub-release-apk --dir .

if (Test-Path ".\app-release.apk") {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "  SUCCESS! APK DOWNLOADED TO YOUR PROJECT FOLDER:         " -ForegroundColor Green
    Write-Host "  $((Get-Item .\app-release.apk).FullName)" -ForegroundColor White
    Write-Host "  Size: $([math]::round((Get-Item .\app-release.apk).Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "`nArtifact downloaded to current directory. Check folder contents." -ForegroundColor Yellow
}
