#!/bin/bash
# ============================================================================
# OpenSSL 3.3 LTS Compilation Script for Windows
# ============================================================================
# 编译OpenSSL 3.3 LTS静态库,供PJSIP和项目使用
#
# Requirements:
#   - MSYS2 with MinGW-w64 toolchain
#   - Perl (for OpenSSL configure)
#
# Output:
#   - Static libraries at C:/openssl3/lib
#   - Headers at C:/openssl3/include
# ============================================================================

set -e
set -x

echo "========================================"
echo "Building OpenSSL 3.3 LTS for Windows"
echo "========================================"

# Configuration
OPENSSL_VERSION=3.3.5
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
DEPS_DIR=/c/video_deps
INSTALL_DIR=/c/openssl3
JOBS=8

# Create deps directory
mkdir -p "$DEPS_DIR"
cd "$DEPS_DIR"

# Download OpenSSL if not exists
if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
    echo "Downloading OpenSSL ${OPENSSL_VERSION}..."

    # Try multiple mirrors
    MIRRORS=(
        "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
        "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
        "https://mirrors.tuna.tsinghua.edu.cn/openssl/source/openssl-${OPENSSL_VERSION}.tar.gz"
    )

    for mirror in "${MIRRORS[@]}"; do
        echo "Trying: $mirror"
        if curl -L --connect-timeout 30 -o "openssl-${OPENSSL_VERSION}.tar.gz" "$mirror"; then
            echo "Download successful from $mirror"
            break
        else
            echo "Failed from $mirror, trying next..."
            rm -f "openssl-${OPENSSL_VERSION}.tar.gz"
        fi
    done

    if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
        echo "ERROR: Failed to download OpenSSL from all mirrors"
        echo "Please manually download from: https://www.openssl.org/source/"
        exit 1
    fi
fi

# Extract
if [ ! -d "openssl-${OPENSSL_VERSION}" ]; then
    echo "Extracting OpenSSL..."
    tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz"
fi

cd "openssl-${OPENSSL_VERSION}"

# Clean previous build
make distclean 2>/dev/null || true

# Configure OpenSSL for MinGW
# 使用no-shared编译静态库,避免运行时依赖DLL
# 添加 -static-libgcc 确保 C 运行库静态链接
echo "Configuring OpenSSL..."
export CFLAGS="-static-libgcc"
export LDFLAGS="-static-libgcc"
./Configure mingw64 \
    --prefix="$INSTALL_DIR" \
    --openssldir="$INSTALL_DIR/ssl" \
    no-shared \
    no-tests \
    -static

# Build
echo "Building OpenSSL (this may take 10-20 minutes)..."
make -j${JOBS}

# Install
echo "Installing OpenSSL to $INSTALL_DIR..."
make install_sw install_ssldirs

# Verify
echo ""
echo "========================================"
echo "Verifying OpenSSL installation..."
echo "========================================"
ls -lh "$INSTALL_DIR"/lib/*.a | head -5
ls -lh "$INSTALL_DIR"/include/openssl/ssl.h

echo ""
echo "========================================"
echo "OpenSSL 3.3 LTS Build Complete!"
echo "========================================"
echo "Install location: $INSTALL_DIR"
echo "Static libraries: $INSTALL_DIR/lib"
echo "Headers: $INSTALL_DIR/include"
echo ""
echo "Next step: Recompile PJSIP with new OpenSSL"
echo "========================================"
