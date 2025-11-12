# Scans Dart files under lib/ for hardcoded local backend URLs
# Exits with code 0 if no problems found, 1 if any matches are detected.

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root

$patterns = @("http://localhost", "http://10.0.2.2", ":3000")
$exclude = @('lib/api_base.dart')

Write-Host "Scanning .dart files under lib/ for hardcoded local URLs...`n"
$found = @()

Get-ChildItem -Path .\lib -Recurse -Filter *.dart | ForEach-Object {
    $file = $_.FullName
    if ($exclude -contains $file.Replace('\','/')) { return }
    $content = Get-Content -Raw -Path $file -ErrorAction SilentlyContinue
    if (-not $content) { return }
    foreach ($p in $patterns) {
        if ($content -match [regex]::Escape($p)) {
            $matches = [regex]::Matches($content, [regex]::Escape($p))
            foreach ($m in $matches) {
                $lineNum = ($content.Substring(0,$m.Index) -split "`n").Count
                $found += [PSCustomObject]@{File = $file; Pattern = $p; Line = $lineNum}
            }
        }
    }
}

if ($found.Count -eq 0) {
    Write-Host "✅ No hardcoded local backend URLs found in Dart files (good)."
    exit 0
} else {
    Write-Host "⚠️ Found hardcoded local URLs in Dart files:`n"
    $found | Format-Table -AutoSize
    Write-Host "`nPlease replace these with imports from lib/api_base.dart or update them as needed."
    exit 1
}
