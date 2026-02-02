# Multi-stage Dockerfile for Status Desktop Android Build

# =============================================================================
# Global build arguments
# =============================================================================
ARG QT_VERSION="6.9.2"
ARG QT_MODULES="qt5compat qtmultimedia qtwebsockets qtpositioning qtshadertools qtimageformats qtwebview qtconnectivity qtlottie qtscxml qtwebchannel"
ARG JAVA_VERSION=17
ARG ANDROID_API_LEVEL=35
ARG ANDROID_NDK_VERSION=27.2.12479018
ARG GOLANG_VERSION="1.24.7"
ARG NIM_VERSION="2.2.4"
ARG NIX_VERSION="2.24.11"

# =============================================================================
# Stage 1: Qt Installation using aqtinstall
# =============================================================================
FROM ubuntu:noble AS qt-install

ARG QT_VERSION QT_MODULES

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN chmod -R 777 /opt

# Install Qt for Android using aqtinstall 
# --autodesktop installs host Qt (gcc_64) needed for cross-compilation
# FIXME: Only installing arm64_v8a as the primary architecture (think about other architectures : armv7, x86, x86_64)
RUN python3 -m venv /tmp/aqt-venv \
 && /tmp/aqt-venv/bin/pip install -U pip setuptools aqtinstall \
 && /tmp/aqt-venv/bin/aqt install-qt linux android ${QT_VERSION} android_arm64_v8a -m ${QT_MODULES} -O /opt/qt --autodesktop --timeout 3000 \
 && rm -rf /tmp/aqt-venv

RUN rm -rf /opt/qt/${QT_VERSION}/gcc_64/qml/QtWebEngine \
 && rm -rf /opt/qt/${QT_VERSION}/gcc_64/lib/libQt6WebEngine* \
 && rm -rf /opt/qt/${QT_VERSION}/gcc_64/lib/cmake/Qt6WebEngine* \
 && rm -rf /opt/qt/${QT_VERSION}/gcc_64/libexec/QtWebEngineProcess \
 && rm -rf /opt/qt/${QT_VERSION}/gcc_64/modules/WebEngine*.json \
 # Remove QtWebEngine dependency from QtWebView qmldir (aqtinstall's QtWebView was built with WebEngine support)
 && sed -i '/depends QtWebEngine/d' /opt/qt/${QT_VERSION}/gcc_64/qml/QtWebView/qmldir \
 && sed -i '/depends QtWebEngine/d' /opt/qt/${QT_VERSION}/android_arm64_v8a/qml/QtWebView/qmldir 2>/dev/null || true

# Clean up unnecessary Qt files to reduce image size (docs, examples)
# Note: Do NOT delete .a files - Qt CMake configs reference them and builds will fail
RUN rm -rf /opt/qt/${QT_VERSION}/gcc_64/doc \
 && rm -rf /opt/qt/${QT_VERSION}/gcc_64/examples \
 && rm -rf /opt/qt/${QT_VERSION}/android_arm64_v8a/doc \
 && rm -rf /opt/qt/${QT_VERSION}/android_arm64_v8a/examples \
 # Remove debug symbols from Qt libraries
 && find /opt/qt/${QT_VERSION} -name "*.debug" -type f -delete 2>/dev/null || true

# =============================================================================
# Stage 2: Final Build Image
# =============================================================================
FROM ubuntu:noble

ARG QT_VERSION
ARG JAVA_VERSION
ARG ANDROID_API_LEVEL
ARG ANDROID_NDK_VERSION
ARG GOLANG_VERSION
ARG NIM_VERSION
ARG NIX_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# Qt environment variables
ENV QT_PATH=/opt/qt \
    QT_VERSION=${QT_VERSION}

ENV QTDIR=${QT_PATH}/${QT_VERSION}/android_arm64_v8a
ENV QT_HOST_PATH=${QT_PATH}/${QT_VERSION}/gcc_64
ENV PATH="${QT_PATH}/${QT_VERSION}/android_arm64_v8a/bin:${QT_PATH}/${QT_VERSION}/gcc_64/bin:${QT_PATH}/${QT_VERSION}/gcc_64/libexec:${PATH}"
ENV QT_PLUGIN_PATH="${QT_PATH}/${QT_VERSION}/gcc_64/plugins"

# Android environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_NDK_ROOT=/opt/android-sdk/ndk/${ANDROID_NDK_VERSION}

# Locale
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# =============================================================================
# Install system dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential cmake ninja-build pkg-config extra-cmake-modules \
    autoconf automake libtool gcc-13 g++-13 \
    # Dev tools
    git git-lfs curl wget unzip file xz-utils jq rsync s3cmd fuse \
    gnupg2 openssh-client ca-certificates locales sudo \
    software-properties-common \
    # Python
    python3 python3-pip python3-venv \
    # Libraries for Qt
    libgl1-mesa-dev libsm6 libice6 libfontconfig1 libdbus-1-3 \
    libssl-dev libz-dev zlib1g-dev \
    libxext6 libxrender1 libxkbcommon-dev libxkbcommon-x11-dev \
    libxcomposite1 libxtst6 libxrandr2 libxcursor1 libxi6 \
    libxcb-randr0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-render-util0 libxcb-shape0 libxcb-render0 libxcb-xinerama0 \
    libxcb-cursor0 libxslt1.1 libxkbfile1 \
    libatk1.0-0 libcups2 libgtk-3-0 libgdk-pixbuf-2.0-0 \
    # GStreamer
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa \
    libpulse-mainloop-glib0 gstreamer1.0-pulseaudio libgstreamer-plugins-base1.0-0 \
    # Database
    libsqlite3-dev libreadline-dev libncurses5-dev libncursesw5-dev \
    unixodbc-dev libpq-dev libbz2-dev \
    # Other
    libnss3 llvm tk-dev \
    # Java and Android
    openjdk-${JAVA_VERSION}-jdk google-android-cmdline-tools-13.0-installer \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Configure locale
# =============================================================================
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

# =============================================================================
# Install Android SDK and NDK
# =============================================================================
RUN yes | sdkmanager --sdk_root=/opt/android-sdk \
    "platforms;android-${ANDROID_API_LEVEL}" \
    "platform-tools" \
    "build-tools;${ANDROID_API_LEVEL}.0.0" \
 && yes | sdkmanager --sdk_root=/opt/android-sdk "ndk;${ANDROID_NDK_VERSION}" \
 && yes | sdkmanager --licenses \
 # Clean up NDK unused files (samples, shader-tools, simpleperf) to save ~500MB
 && rm -rf /opt/android-sdk/ndk/${ANDROID_NDK_VERSION}/shader-tools \
 && rm -rf /opt/android-sdk/ndk/${ANDROID_NDK_VERSION}/simpleperf \
 && rm -rf /opt/android-sdk/ndk/${ANDROID_NDK_VERSION}/sources/cxx-stl/llvm-libc++/test \
 && rm -rf /opt/android-sdk/.android

# =============================================================================
# Copy Qt from install stage
# =============================================================================
RUN chmod -R 777 /opt && mkdir -p /opt/qt/${QT_VERSION}
COPY --from=qt-install /opt/qt/${QT_VERSION} /opt/qt/${QT_VERSION}/

# Configure Qt library path
RUN echo "/opt/qt/${QT_VERSION}/gcc_64/lib" > /etc/ld.so.conf.d/qt.conf && ldconfig

# =============================================================================
# Install Golang
# =============================================================================
RUN GOLANG_SHA256="da18191ddb7db8a9339816f3e2b54bdded8047cdc2a5d67059478f8d1595c43f" \
 && GOLANG_TARBALL="go${GOLANG_VERSION}.linux-amd64.tar.gz" \
 && wget -q "https://dl.google.com/go/${GOLANG_TARBALL}" \
 && echo "${GOLANG_SHA256} ${GOLANG_TARBALL}" | sha256sum -c \
 && tar -C /usr/local -xzf "${GOLANG_TARBALL}" \
 && rm "${GOLANG_TARBALL}" \
 && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
 && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Install Go tools and clean up Go module cache to save space
RUN /usr/local/go/bin/go install github.com/go-bindata/go-bindata/v3/go-bindata@latest \
 && /usr/local/go/bin/go install go.uber.org/mock/mockgen@v0.4.0 \
 && /usr/local/go/bin/go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.1 \
 && cp /root/go/bin/* /usr/local/bin/ \
 && rm -rf /root/go /root/.cache/go-build

# =============================================================================
# Install Protoc (from GitHub releases, includes well-known types)
# =============================================================================
RUN PROTOC_SHA256="75d8a9d7a2c42566e46411750d589c51276242d8b6247a5724bac0f9283e05a8" \
 && PROTOC_TARBALL="protoc-3.20.0-linux-x86_64.zip" \
 && wget -q -L "https://github.com/protocolbuffers/protobuf/releases/download/v3.20.0/${PROTOC_TARBALL}" \
 && echo "${PROTOC_SHA256} ${PROTOC_TARBALL}" | sha256sum -c \
 && unzip -d /usr/local "${PROTOC_TARBALL}" \
 && rm "${PROTOC_TARBALL}"

# =============================================================================
# Create Jenkins user
# =============================================================================
RUN groupadd -g 1001 jenkins \
 && useradd --create-home -u 1001 -g 1001 -s /bin/bash jenkins \
 && echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && mkdir /nix && chown jenkins:jenkins /nix

# =============================================================================
# Switch to jenkins user for user-specific installations
# =============================================================================
USER jenkins
WORKDIR /home/jenkins
ENV HOME="/home/jenkins"

# Build OpenSSL for Android arm64-v8a (only keep lib and include)
RUN set -e \
 && git clone --depth 1 --branch openssl-3.0.15 https://github.com/openssl/openssl.git \
 && mkdir -p openssl-output/arm64-v8a \
 && cd openssl \
 && export ANDROID_NDK_HOME=${ANDROID_NDK_ROOT} \
 && export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH \
 && ./Configure android-arm64 \
    -D__ANDROID_API__=21 \
    --prefix=/home/jenkins/openssl-output/arm64-v8a \
    --openssldir=/home/jenkins/openssl-output/arm64-v8a \
    no-shared no-tests \
 && make -j$(nproc) \
 && make install_sw \
 && cd .. && rm -rf openssl \
 # Only keep lib and include, remove ssl config files
 && rm -rf /home/jenkins/openssl-output/arm64-v8a/bin \
 && rm -rf /home/jenkins/openssl-output/arm64-v8a/ssl

ENV OPENSSL_LIB_DIR="/home/jenkins/openssl-output/arm64-v8a/lib"
ENV OPENSSL_INC_DIR="/home/jenkins/openssl-output/arm64-v8a/include"

# Install Nim and clean up choosenim downloads
RUN curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y \
 && /home/jenkins/.nimble/bin/choosenim ${NIM_VERSION} \
 && rm -rf /home/jenkins/.choosenim/downloads

# Install Nix and clean up Nix store cache
RUN curl -s https://nixos.org/releases/nix/nix-${NIX_VERSION}/install | sh -s -- --no-daemon \
 && rm -rf /home/jenkins/.cache/nix

# =============================================================================
# Switch back to root for final configuration
# =============================================================================
USER root

# Create symlinks for Nim tools
RUN ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/nim /usr/local/bin/nim \
 && ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/nimble /usr/local/bin/nimble \
 && ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/choosenim /usr/local/bin/choosenim \
 && chmod 755 /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/* \
 && chown -R root:root /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin

# Set GCC alternatives
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-13

# =============================================================================
# Final PATH and environment
# =============================================================================
ENV PATH="/opt/qt/${QT_VERSION}/android_arm64_v8a/bin:/opt/qt/${QT_VERSION}/gcc_64/bin:/opt/qt/${QT_VERSION}/gcc_64/libexec:/usr/local/go/bin:/home/jenkins/go/bin:/home/jenkins/.nimble/bin:/home/jenkins/.nix-profile/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/usr/local/bin:${PATH}"
ENV PKG_CONFIG_PATH="/opt/qt/${QT_VERSION}/android_arm64_v8a/lib/pkgconfig"
ENV ARCH=arm64

USER jenkins
WORKDIR /home/jenkins

ENTRYPOINT ["/bin/bash", "-l", "-c"]

LABEL maintainer="siddarth@status.im"
LABEL source="https://github.com/status-im/status-app"
LABEL description="Build image for the Status Android App"
