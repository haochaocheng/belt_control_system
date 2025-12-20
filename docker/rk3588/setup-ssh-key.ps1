# Setup SSH Key for Passwordless Login

$sshDir = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDir\id_rsa"
$pubKeyFile = "$sshDir\id_rsa.pub"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup SSH Passwordless Login" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create .ssh directory if not exists
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
    Write-Host "Created .ssh directory" -ForegroundColor Green
}

# Generate SSH key if not exists
if (!(Test-Path $keyFile)) {
    Write-Host "Generating SSH key..." -ForegroundColor Yellow
    & ssh-keygen -t rsa -b 2048 -f $keyFile -N '""'
    Write-Host "SSH key generated" -ForegroundColor Green
} else {
    Write-Host "SSH key already exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next: Upload public key to device (192.168.10.170)" -ForegroundColor Yellow
Write-Host "You will need to enter the password (pi) ONE last time" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Enter to continue..."
Read-Host

# Upload public key
Write-Host "Uploading public key..." -ForegroundColor Yellow
$pubKey = Get-Content $pubKeyFile
$pubKey | ssh pi@192.168.10.170 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Setup Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Testing passwordless login..." -ForegroundColor Yellow
    ssh pi@192.168.10.170 "echo 'Passwordless login works!'"
    Write-Host ""
    Write-Host "Now you can run deploy scripts without password prompts" -ForegroundColor Cyan
} else {
    Write-Host "Failed to upload public key" -ForegroundColor Red
}

Write-Host ""
