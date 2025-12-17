# Smart Energy System - Test Runner Script for PowerShell
# This script runs all unit tests with detailed output

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Smart Energy System - Unit Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
$flutterExists = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterExists) {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter from https://flutter.dev" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Running all unit tests..." -ForegroundColor Yellow
Write-Host ""

# Run tests with expanded reporter for detailed output
flutter test --reporter expanded

# Capture exit code
$testExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test execution completed!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check exit code
if ($testExitCode -eq 0) {
    Write-Host "✓ All tests PASSED!" -ForegroundColor Green
} else {
    Write-Host "✗ Some tests FAILED!" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
exit $testExitCode
