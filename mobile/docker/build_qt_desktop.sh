#!/bin/bash

#
# Build Qt 6.9.2 for desktop (host platform) - required for Android cross-compilation
# Based on https://github.com/carlonluca/docker-qt/blob/master/6.9.2/build_6.9.2_amd64.sh
#

set -e

qt_version="6.9.2"
qt_branch="v${qt_version}"

echo "Building Qt ${qt_version} for desktop (host platform)..."

cd /root

# Clone Qt source if not already present
if [ ! -d "qt5" ]; then
    echo "Cloning Qt source code..."
    git clone https://code.qt.io/qt/qt5.git
fi

cd qt5
git checkout ${qt_branch}
# Initialize repository - Android build expects all modules
perl init-repository

# Create build directory
mkdir -p /root/qt5_build
cd /root/qt5_build

# Configure Qt for desktop build
echo "Configuring Qt ${qt_version} for desktop..."
/root/qt5/configure \
    -prefix /opt/qt/${qt_version}/gcc_64 \
    -release \
    -opensource \
    -confirm-license \
    -nomake examples \
    -nomake tests \
    -skip qtdoc \
    -skip qtwayland \
    -openssl-linked \
    -platform linux-g++ \
    -- -DCMAKE_BUILD_TYPE=Release

# Build Qt
echo "Building Qt ${qt_version}... This will take a while."
cmake --build . --parallel $(nproc)

# Install Qt
echo "Installing Qt ${qt_version} to /opt/qt/${qt_version}/gcc_64..."
cmake --install .

# Clean up build directory to save space
cd /root
rm -rf /root/qt5_build

# Export the built Qt as a tar archive if export directory exists
if [ -d "/root/export" ]; then
    echo "Creating Qt export archive..."
    cd /opt/qt/${qt_version}
    tar czf /root/export/Qt-amd64-${qt_version}.tar.xz gcc_64
    echo "Qt desktop build exported to /root/export/Qt-amd64-${qt_version}.tar.xz"
fi

echo "Qt ${qt_version} desktop build completed successfully!"