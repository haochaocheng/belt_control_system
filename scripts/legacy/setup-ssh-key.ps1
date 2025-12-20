# Setup SSH passwordless login
$ErrorActionPreference = "Stop"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "SSH passwordless login setup" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Device list
$devices = @(
    @{IP="192.168.10.188"; User="linaro"; Name="Device 188"}
)

# Check if SSH key exists
$sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
$sshPubKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"

if (-not (Test-Path $sshKeyPath)) {
    Write-Host "SSH key not found, generating..." -ForegroundColor Yellow
    Write-Host ""

    # Create .ssh directory
    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir | Out-Null
    }

    Write-Host "Press Enter to use default settings (no password)" -ForegroundColor White
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host "SSH key generation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "SSH key generated" -ForegroundColor Green
} else {
    Write-Host "Found existing SSH key: $sshKeyPath" -ForegroundColor Green
}

Write-Host ""

# Read public key
$pubKey = Get-Content $sshPubKeyPath -Raw
$pubKey = $pubKey.Trim()

# Copy to each device
foreach ($device in $devices) {
    $deviceAddr = "$($device.User)@$($device.IP)"
    Write-Host "Configuring $($device.Name) ($deviceAddr)..." -ForegroundColor Cyan
    Write-Host "  Please enter device password: linaro" -ForegroundColor Yellow
    Write-Host "  (Password input is hidden - you won't see any characters)" -ForegroundColor Gray

    # Create .ssh directory on remote
    ssh -o PreferredAuthentications=password $deviceAddr 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed: Cannot connect to $($device.Name)" -ForegroundColor Red
        continue
    }

    # Save key to temp file and copy
    $tempKeyFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempKeyFile -Value $pubKey -NoNewline
    scp $tempKeyFile "${deviceAddr}:/tmp/temp_pubkey"
    ssh $deviceAddr 'cat /tmp/temp_pubkey >> ~/.ssh/authorized_keys && rm /tmp/temp_pubkey && chmod 600 ~/.ssh/authorized_keys'
    Remove-Item $tempKeyFile

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed: Cannot configure key" -ForegroundColor Red
        continue
    }

    # Test
    Write-Host "  Testing passwordless login..." -ForegroundColor White
    $testResult = ssh -o BatchMode=yes -o ConnectTimeout=5 $deviceAddr 'echo OK' 2>$null

    if ($testResult -eq "OK") {
        Write-Host "  Success! Passwordless login configured" -ForegroundColor Green
    } else {
        Write-Host "  Warning: Test failed, please check manually" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "===========================================" -ForegroundColor Green
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now connect without password:" -ForegroundColor White
foreach ($device in $devices) {
    Write-Host "  ssh $($device.User)@$($device.IP)" -ForegroundColor Cyan
}
Write-Host ""
