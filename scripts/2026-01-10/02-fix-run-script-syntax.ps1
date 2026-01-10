# UTF-8 BOM
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Fixing run-ubuntu24-apt.sh CRLF issue..." -ForegroundColor Cyan

$DeviceUser = "linaro"
$DevicePassword = "linaro"
$DeviceIP = "192.168.10.188"
$AppImageName = "belt-control"
$AppImageTag = "v3.5-apt"

# Extract script from build-ubuntu24-apt.ps1
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)
$BuildScript = Join-Path $ProjectRoot "build-ubuntu24-apt.ps1"
$BuildScriptContent = Get-Content $BuildScript -Raw

$StartMarker = '$runScript = @'''
$EndMarker = '''@'
$StartIndex = $BuildScriptContent.IndexOf($StartMarker)
$EndIndex = $BuildScriptContent.IndexOf($EndMarker, $StartIndex + $StartMarker.Length)

if ($StartIndex -ge 0 -and $EndIndex -gt $StartIndex) {
    $runScript = $BuildScriptContent.Substring($StartIndex + $StartMarker.Length, $EndIndex - $StartIndex - $StartMarker.Length).Trim()

    # Replace placeholders
    $runScript = $runScript -replace "DEVICE_USER_PLACEHOLDER", $DeviceUser
    $runScript = $runScript -replace "IMAGE_NAME_PLACEHOLDER", $AppImageName
    $runScript = $runScript -replace "IMAGE_TAG_PLACEHOLDER", $AppImageTag

    # Convert to Unix LF
    $runScript = $runScript -replace "`r`n", "`n"

    Write-Host "Script extracted, lines: $(($runScript -split "`n").Count)" -ForegroundColor Green

    # Save to temp file (UTF8 without BOM, Unix LF)
    $TempScriptFile = Join-Path $env:TEMP "run-ubuntu24-apt-fixed.sh"
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllText($TempScriptFile, $runScript, $Utf8NoBomEncoding)

    # Verify line endings
    $FileBytes = [System.IO.File]::ReadAllBytes($TempScriptFile)
    $CrCount = ($FileBytes | Where-Object { $_ -eq 0x0D }).Count
    $LfCount = ($FileBytes | Where-Object { $_ -eq 0x0A }).Count

    Write-Host "Line endings: CR=$CrCount LF=$LfCount" -ForegroundColor $(if ($CrCount -eq 0) { "Green" } else { "Red" })

    if ($CrCount -gt 0) {
        Write-Host "ERROR: File still contains CR characters!" -ForegroundColor Red
        Remove-Item $TempScriptFile -Force
        exit 1
    }

    # Upload to device
    Write-Host "Uploading to device $DeviceIP..." -ForegroundColor Yellow
    $env:SSHPASS = $DevicePassword

    & sshpass -e scp $TempScriptFile "${DeviceUser}@${DeviceIP}:/home/$DeviceUser/run-ubuntu24-apt.sh"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK: Script uploaded" -ForegroundColor Green

        # Set execute permission
        & sshpass -e ssh "${DeviceUser}@${DeviceIP}" "chmod +x /home/$DeviceUser/run-ubuntu24-apt.sh"
        Write-Host "OK: Permission set" -ForegroundColor Green

        # Verify syntax
        Write-Host "Verifying script syntax..." -ForegroundColor Yellow
        & sshpass -e ssh "${DeviceUser}@${DeviceIP}" "bash -n /home/$DeviceUser/run-ubuntu24-apt.sh"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK: Syntax check passed!" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Syntax check failed" -ForegroundColor Red
        }
    } else {
        Write-Host "ERROR: Upload failed" -ForegroundColor Red
    }

    # Cleanup
    Remove-Item $TempScriptFile -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Fix complete. Ready to test." -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot extract script content" -ForegroundColor Red
    exit 1
}
