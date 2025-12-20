#!/bin/bash
# Build Belt Control v3.3 on RK3588 device (local compilation)
# This script compiles the application directly on the ARM64 device

set -e

echo "=========================================="
echo "Belt Control v3.3 - Device Build"
echo "=========================================="
echo ""

# Configuration
BUILD_DIR="/home/linaro/belt-control-build-v3.3"
SOURCE_DIR="/home/linaro/belt-control-source"
DEPLOY_DIR="/home/linaro/belt-control-qt6"

# Step 1: Install build dependencies
echo "Step 1/5: Checking build dependencies..."
if ! command -v cmake &> /dev/null; then
    echo "  Installing CMake..."
    sudo apt-get update
    sudo apt-get install -y cmake build-essential pkg-config
fi

if ! command -v qmake6 &> /dev/null; then
    echo "  Installing Qt6 development packages..."
    sudo apt-get install -y qt6-base-dev qt6-declarative-dev qt6-multimedia-dev
fi

echo "  OK Dependencies installed"
echo ""

# Step 2: Prepare source directory
echo "Step 2/5: Preparing source code..."

if [ ! -d "$SOURCE_DIR" ]; then
    echo "  ERROR: Source directory not found at $SOURCE_DIR"
    echo "  Please upload source code to the device first."
    exit 1
fi

cd "$SOURCE_DIR"
echo "  OK Source directory ready"
echo ""

# Step 3: Configure CMake
echo "Step 3/5: Configuring build..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="/opt/qt6" \
    -DENABLE_SHERPA_ONNX=ON

if [ $? -ne 0 ]; then
    echo "  ERROR: CMake configuration failed!"
    exit 1
fi

echo "  OK Build configured"
echo ""

# Step 4: Build
echo "Step 4/5: Compiling..."
echo "  This may take 10-15 minutes..."

cmake --build . -j$(nproc)

if [ $? -ne 0 ]; then
    echo "  ERROR: Build failed!"
    exit 1
fi

# Find binary
BINARY_PATH=$(find "$BUILD_DIR" -name "belt_control_system" -type f | head -1)
if [ -z "$BINARY_PATH" ]; then
    echo "  ERROR: Binary not found after build!"
    exit 1
fi

echo "  OK Build successful"
echo "  Binary: $BINARY_PATH"
echo ""

# Step 5: Deploy
echo "Step 5/5: Deploying..."

cp "$BINARY_PATH" "$DEPLOY_DIR/belt_control_system"
chmod +x "$DEPLOY_DIR/belt_control_system"

echo "  OK Binary deployed to $DEPLOY_DIR"
echo ""

# Create Dockerfile.v3.3
cat > "$DEPLOY_DIR/Dockerfile.v3.3" <<'EOF'
# Belt Control v3.3 - With Screen Rotation Fix
FROM belt-control-base:trixie-noglib-v3.0

WORKDIR /app

# 复制应用程序
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system

# 复制系统库(包含GLib 2.80)
COPY lib /app/libs

# 复制Qt6运行时
COPY qt6/lib /opt/qt6/lib
COPY qt6/plugins /opt/qt6/plugins
COPY qt6/qml /opt/qt6/qml

# 创建libpulsecommon符号链接
RUN ln -s /usr/lib/aarch64-linux-gnu/pulseaudio/libpulsecommon-17.0.so /usr/lib/aarch64-linux-gnu/libpulsecommon-16.1.so || true

# 关键修复1: 在/app目录下创建qml和xcbglintegrations符号链接
RUN ln -s /opt/qt6/qml /app/qml
RUN ln -s /opt/qt6/plugins/xcbglintegrations /app/xcbglintegrations

# 关键修复2: 强制优先使用打包的GLib 2.80库
ENV LD_PRELOAD=/app/libs/libglib-2.0.so.0:/app/libs/libgobject-2.0.so.0:/app/libs/libgio-2.0.so.0:/app/libs/libgmodule-2.0.so.0
ENV LD_LIBRARY_PATH=/app/libs:/opt/qt6/lib
ENV QT_PLUGIN_PATH=/opt/qt6/plugins
ENV QML2_IMPORT_PATH=/opt/qt6/qml
ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_INTEGRATION=eglfs_kms

# 创建配置和数据目录
RUN mkdir -p /app/config /app/data

CMD ["/app/belt_control_system"]
EOF

echo "  OK Dockerfile.v3.3 created"
echo ""

# Build Docker image
echo "Building Docker image..."
cd "$DEPLOY_DIR"
docker build -f Dockerfile.v3.3 -t belt-control:v3.3 .

if [ $? -ne 0 ]; then
    echo "  ERROR: Docker build failed!"
    exit 1
fi

echo "  OK Docker image built"
echo ""

# Create run script
cat > "$DEPLOY_DIR/run-v3.3.sh" <<'EOF'
#!/bin/bash
# Run Belt Control v3.3 with screen rotation fix

docker run --rm \
  --privileged \
  --group-add 44 \
  --device=/dev/mali0 \
  --device=/dev/fb0 \
  --device=/dev/dri/card0 \
  --device=/dev/dri/renderD128 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /run/udev:/run/udev:ro \
  belt-control:v3.3
EOF

chmod +x "$DEPLOY_DIR/run-v3.3.sh"

echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Application: belt-control:v3.3"
echo "Binary: $DEPLOY_DIR/belt_control_system"
echo ""
echo "To run:"
echo "  cd $DEPLOY_DIR"
echo "  ./run-v3.3.sh"
echo ""
echo "Changes in v3.3:"
echo "  - Auto-detects 800x1280 screen resolution"
echo "  - Applies 270° rotation for correct landscape display"
echo "  - QML-level transformation"
echo ""
