# Minimal Docker deployment
param([string]$Device = "192.168.10.188")

Write-Host "Docker Deploy to $Device" -ForegroundColor Cyan

$root = "e:/2025/3_gongkongji/belt_control_system"
$ctx = "$root/docker_minimal"

# Clean
if (Test-Path $ctx) { Remove-Item -Recurse -Force $ctx }
New-Item -ItemType Directory $ctx | Out-Null

# Minimal Dockerfile
@'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y libqt6core6t64 libqt6gui6t64 libqt6widgets6t64 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system
CMD ["/app/belt_control_system"]
'@ | Out-File -Encoding UTF8 "$ctx/Dockerfile"

# Copy binary
Copy-Item "$root/build_rk3588_new/bin_arm64/belt_control_system" "$ctx/"

# Build
docker build -t belt:min $ctx
docker save -o "$root/belt.tar" belt:min

# Deploy
scp "$root/belt.tar" "linaro@${Device}:/tmp/"
ssh "linaro@${Device}" "sudo docker load -i /tmp/belt.tar && sudo docker run -d --name belt --privileged belt:min && rm /tmp/belt.tar"

# Clean
Remove-Item "$root/belt.tar" -ErrorAction SilentlyContinue
Remove-Item -Recurse $ctx -ErrorAction SilentlyContinue

Write-Host "Done! View: ssh linaro@$Device 'sudo docker logs belt'" -ForegroundColor Green