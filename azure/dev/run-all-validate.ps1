#--------------------------------------------------------------
# 모든 dev 스택에 대해 terraform init -backend=false && terraform validate 실행
# 실행 위치: 이 스크립트가 있는 디렉터리(azure/dev)를 기준으로 각 스택 폴더에서 실행
#--------------------------------------------------------------
$ErrorActionPreference = "Continue"
$stacks = @("network", "storage", "shared-services", "apim", "ai-services", "compute", "connectivity")
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

foreach ($s in $stacks) {
    $dir = Join-Path $scriptDir $s
    if (-not (Test-Path $dir)) {
        Write-Host "[SKIP] $s - directory not found" -ForegroundColor Yellow
        continue
    }
    Write-Host ""
    Write-Host "=== $s ===" -ForegroundColor Cyan
    Push-Location $dir
    terraform init -backend=false 2>&1 | Out-Null
    $result = terraform validate 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Success! The configuration is valid." -ForegroundColor Green
    } else {
        Write-Host $result -ForegroundColor Red
    }
    Pop-Location
}
Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
