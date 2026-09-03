param(
  [switch]$Strict
)

$ErrorActionPreference = "Stop"
$missing = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Require-Env($name) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    $missing.Add($name)
  }
}

function Warn-DevValue($name, $pattern, $message) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if ($value -and ($value -match $pattern)) {
    $warnings.Add("${name}: $message")
  }
}

Require-Env "SUPABASE_URL"
Require-Env "SUPABASE_PUBLISHABLE_KEY"
Require-Env "SUPABASE_SERVICE_ROLE_KEY"

Warn-DevValue "SUPABASE_URL" "localhost|127\.0\.0\.1|supabase\.co$" "verify this points to the intended production project."
Warn-DevValue "DEV_OTP_CODE" "^11111$" "dev OTP must not be enabled in production."
Warn-DevValue "OTP_BYPASS_CODE" "^11111$" "OTP bypass must not be enabled in production."

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
  $warnings.Add("Flutter is not installed/on PATH here; run flutter analyze/test/build on a Flutter machine.")
}

if ($missing.Count -gt 0) {
  Write-Host "Missing required environment variables:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

if ($warnings.Count -gt 0) {
  Write-Host "Warnings:" -ForegroundColor Yellow
  $warnings | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
  if ($Strict) { exit 1 }
}

Write-Host "Production environment check completed." -ForegroundColor Green
