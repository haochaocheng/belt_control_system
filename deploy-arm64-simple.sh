#!/bin/bash
# 在设备188上直接构建ARM64镜像

echo "Creating ARM64 Docker build context..."

# 创建临时目录
rm -rf /tmp/arm64_deploy
mkdir -p /tmp/arm64_deploy

# 创建Dockerfile
cat > /tmp/arm64_deploy/Dockerfile << 'EOF'
FROM arm64v8/ubuntu:24.04
RUN apt-get update && apt-get install -y libstdc++6 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system
CMD ["/app/belt_control_system"]
EOF

# 复制二进制文件（需要你先传输）
echo "请先执行以下命令传输二进制文件："
echo "scp e:/2025/3_gongkongji/belt_control_system/build_rk3588_new/bin_arm64/belt_control_system linaro@192.168.10.188:/tmp/arm64_deploy/"

echo "然后在设备上执行："
echo "cd /tmp/arm64_deploy"
echo "sudo docker build -t belt:arm64 ."
echo "sudo docker stop belt 2>/dev/null; sudo docker rm belt 2>/dev/null"
echo "sudo docker run -d --name belt --privileged -v /dev:/dev belt:arm64"
echo "sudo docker logs -f belt"