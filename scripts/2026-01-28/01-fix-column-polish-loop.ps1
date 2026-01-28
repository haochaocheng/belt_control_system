# Fix QML Column polish() loop warnings
# UTF-8 with BOM
$OutputEncoding = [System.Text.UTF8Encoding]::new($true)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Write-Host "========================================"
Write-Host "Batch fix QML Column polish() warnings"
Write-Host "========================================"
Write-Host ""

# File list
$files = @(
    "src\qml\components\device_info\pages\BasicConfigTab.qml",
    "src\qml\components\device_info\pages\CurrentProtectionTab.qml",
    "src\qml\components\device_info\pages\FrontBearingTempTab.qml",
    "src\qml\components\device_info\pages\MotorListPanel.qml",
    "src\qml\components\device_info\pages\MotorTempTab.qml",
    "src\qml\components\device_info\pages\PhaseAWindingTab.qml",
    "src\qml\components\device_info\pages\PhaseBWindingTab.qml",
    "src\qml\components\device_info\pages\PhaseCWindingTab.qml",
    "src\qml\components\device_info\pages\RearBearingTempTab.qml",
    "src\qml\components\device_info\pages\XAxisVibrationTab.qml"
)

$successCount = 0

foreach ($file in $files) {
    Write-Host "Processing: $file"

    if (-not (Test-Path $file)) {
        Write-Host "  File not found"
        continue
    }

    # Read file
    $content = Get-Content $file -Raw -Encoding UTF8

    # Check if already fixed
    if ($content -match "FIX 100\.300\.59") {
        Write-Host "  Already fixed, skip"
        continue
    }

    # Fix 1: Replace padding: 30
    $content = $content -replace 'padding: 30', 'leftPadding: 30
        rightPadding: 30
        topPadding: 30
        // FIX 100.300.59: Use separate padding to avoid polish() loop'

    # Fix 2: Replace Row width
    $content = $content -replace '(?<=Row\s*\{[^\}]*?)width:\s*parent\.width(?!\s*-)', 'width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding'

    # Save file
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)

    Write-Host "  Fixed"
    $successCount++
}

Write-Host ""
Write-Host "========================================"
Write-Host "Done! Fixed $successCount files"
Write-Host "========================================"
