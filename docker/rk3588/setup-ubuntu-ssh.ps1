# Setup SSH Key for Ubuntu Machine (192.168.10.155)

$pubKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
$ubuntuHost = "192.168.10.155"
$ubuntuUser = "linaro"
$ubuntuPass = "linaro"

Write-Host "Uploading SSH public key to Ubuntu machine..." -ForegroundColor Yellow

# Read public key
$pubKey = Get-Content $pubKeyFile -Raw

# Upload public key using echo (避免交互式输入)
$setupCmd = "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh && echo 'SSH key configured'"

# 使用plink或直接通过ssh
$env:SSHPASS = $ubuntuPass
echo "linaro" | ssh -o StrictHostKeyChecking=no ${ubuntuUser}@${ubuntuHost} $setupCmd 2>&1

Write-Host ""
Write-Host "Testing passwordless login..." -ForegroundColor Yellow
ssh ${ubuntuUser}@${ubuntuHost} "echo 'Success! Passwordless login works'"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SSH Setup Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "Note: You may still need to enter password once more" -ForegroundColor Yellow
}

Write-Host ""
