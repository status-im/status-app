# Multi-stage Dockerfile for Status Desktop Android Build

# =============================================================================
# Global build arguments used across multiple stages
# =============================================================================
ARG QTVER=6.9.2
ARG TARGETARCH=amd64
ARG JAVA_VERSION=17
ARG ANDROID_API_LEVEL=35
ARG ANDROID_NDK_VERSION=27.2.12479018
ARG GOLANG_VERSION="1.24.7"
ARG NIM_VERSION="2.2.4"
ARG NIX_VERSION="2.24.11"

# =============================================================================
# Stage 1: AppImage Builder Base
# inspired by https://github.com/carlonluca/docker-qt/blob/master/appimage-builder/Dockerfile_noble
# =============================================================================
FROM ubuntu:noble AS appimage-builder
RUN \
    apt-get update \
 && apt-get -y install python3-pip \
    python3.12-venv \
    strace \
    patchelf \
    squashfs-tools \
    zsync \
    cmake \
    git \
 && export MAKEFLAGS="-j$(nproc)" \
 && python3 -m venv venv && venv/bin/pip3 install git+https://github.com/AppImageCrafters/appimage-builder.git@main

RUN \
    apt-get -y autoremove \
 && apt-get -y autoclean \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 2: Qt Dev Base - extends appimage-builder
# inspired by https://github.com/carlonluca/docker-qt/blob/master/base/Dockerfile_noble_17-35-27.2.12479018
# =============================================================================
FROM appimage-builder AS qt-dev-base

ARG TARGETARCH
ARG JAVA_VERSION
ARG ANDROID_API_LEVEL
ARG ANDROID_NDK_VERSION

WORKDIR /root

RUN \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
        build-essential cmake freeglut3-dev gdb iputils-ping libgl1-mesa-dev \
        libglu1-mesa-dev libjpeg-dev libmysqlclient-dev libnss3-dev libopus-dev \
        libpng-dev libsqlite3-dev libssl-dev libx11-xcb-dev libxcb-xinerama0-dev \
        libxcb-xkb-dev libxcb1-dev libxcursor-dev libxi-dev libxml2-dev libxrender-dev \
        libxslt-dev lzip mesa-common-dev nano perl python3 valgrind wget zlib1g-dev \
        '^libxcb.*-dev' libxkbcommon-dev libxkbcommon-x11-dev wget libwayland-dev ninja-build && \
    apt-get -y install flex bison gperf libicu-dev libxslt-dev ruby && \
    apt-get -y install libxcursor-dev libxcomposite-dev libxdamage-dev libxrandr-dev \
        libxtst-dev libxss-dev libdbus-1-dev libevent-dev libfontconfig1-dev \
        libcap-dev libpulse-dev libudev-dev libpci-dev libnss3-dev libasound2-dev \
        libegl1-mesa-dev gperf bison nodejs && \
    apt-get -y install libasound2-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev libcups2-dev \
        libavformat60 libavcodec60 libavutil58 libswresample4 libswscale7 libavdevice60 \
        libmng2 libwebp7 libxcb-xinput0 libwebpmux3 libvpx9 libzstd1 libpcre2-16-0 libxshmfence1 libclang1 \
        libllvm16t64 libxkbfile1 libbluetooth3 libsctp1 libsnappy1v5 libmd4c0 libmd4c-html0 libharfbuzz0b libharfbuzz-subset0 \
        libminizip1 libb2-1 libva2 && \
    apt-get install -y protobuf-compiler curl

# webengine
RUN apt-get install zlib1g-dev libcurl4-openssl-dev libwebpdemux2 -y

ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_NDK_ROOT=/opt/android-sdk/ndk/${ANDROID_NDK_VERSION}

RUN \
    if [ "$TARGETARCH" != "arm64" ]; then \
        export DEBIAN_FRONTEND=noninteractive \
 &&     export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64 \
 &&     apt-get update \
 &&     apt-get install -y git git-lfs ccache \
 &&     apt-get install -y openjdk-${JAVA_VERSION}-jdk google-android-cmdline-tools-13.0-installer; \
   fi

# Android
RUN \
    if [ "$TARGETARCH" != "arm64" ]; then \
        export DEBIAN_FRONTEND=noninteractive \
 &&     export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64 \
 &&     yes | sdkmanager --sdk_root=/opt/android-sdk "platforms;android-${ANDROID_API_LEVEL}" "platform-tools" "build-tools;${ANDROID_API_LEVEL}.0.0" \
 &&     export ANDROID_SDK_ROOT=/opt/android-sdk \
 &&     yes | sdkmanager --sdk_root=/opt/android-sdk "ndk;${ANDROID_NDK_VERSION}" \
 &&     export ANDROID_NDK_ROOT=/opt/android-sdk/ndk/${ANDROID_NDK_VERSION} \
 &&     yes | sdkmanager --licenses; \
    fi

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN \
    apt-get -y autoremove \
 && apt-get -y autoclean \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 3: Qt Builder - builds Qt from source
# =============================================================================
FROM qt-dev-base AS qt-builder

ARG QTVER

COPY build_qt_*.sh /root/scripts/

# Build Qt from source
RUN \
    echo "Building Qt from source..." && \
    mkdir -p /root/export && \
    cd /root && \
    /root/scripts/build_qt_android.sh && \
    if [ -f "/root/scripts/build_qt_desktop.sh" ]; then \
        /root/scripts/build_qt_desktop.sh; \
    fi

# =============================================================================
# Stage 4: Qt Export - creates Qt tar.xz files from built Qt
# =============================================================================
FROM scratch AS qt-export

# Copy Qt exports from builder stage
COPY --from=qt-builder /root/export/ /qt_export/

# =============================================================================
# Stage 5: Qt Installation - installs Qt from exports
# inspired by https://github.com/carlonluca/docker-qt/blob/master/Dockerfile_6.9.2
# =============================================================================
FROM qt-dev-base AS qt-installation

ARG QTVER

# Get Qt exports from the qt-export stage
COPY --from=qt-export /qt_export/ /root/qt_export/

# Extract Qt if the tar.xz files exist
RUN \
    mkdir -p /opt/qt/$QTVER && \
    if [ -f "/root/qt_export/Qt-android-$QTVER.tar.xz" ]; then \
        echo "Installing Qt Android from export..."; \
        cd /opt/qt/$QTVER && \
        tar xvfp /root/qt_export/Qt-android-$QTVER.tar.xz; \
    else \
        echo "No Qt Android export found, skipping..."; \
    fi && \
    if [ -f "/root/qt_export/Qt-amd64-$QTVER.tar.xz" ]; then \
        echo "Installing Qt desktop from export..."; \
        cd /opt/qt/$QTVER && \
        tar xvfp /root/qt_export/Qt-amd64-$QTVER.tar.xz; \
    else \
        echo "No Qt desktop export found, skipping..."; \
    fi && \
    rm -rf /root/qt_export

RUN \
    apt-get -y autoremove \
 && apt-get -y autoclean \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/*

# paths for host Qt (used for Android cross-compilation)
ENV PATH="${PATH}:/opt/qt/$QTVER/gcc_64/bin:/opt/qt/$QTVER/gcc_64/libexec"
ENV QT_HOST_PATH="/opt/qt/$QTVER/gcc_64/"
ENV QT_PLUGIN_PATH="/opt/qt/$QTVER/gcc_64/plugins"

ENTRYPOINT ["/bin/bash", "-l", "-c"]
WORKDIR /root

# =============================================================================
# Stage 4: Nim Runtime Environment - extends qt-installation
# =============================================================================
FROM qt-installation AS nim-runtime

ARG QTVER
ARG GOLANG_VERSION
ARG NIM_VERSION
ARG NIX_VERSION

LABEL description="Complete Android build environment with Qt, Nim, and all tooling"
LABEL qt.version="${QTVER}"
LABEL nim.version="${NIM_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive

# Create jenkins user with specific UID/GID for compatibility
RUN groupadd -g 1001 jenkins && useradd -r -g jenkins -m -d /home/jenkins -s /bin/bash -u 1001 jenkins

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    wget \
    build-essential \
    software-properties-common \
    gnupg2 \
    ca-certificates \
    locales \
    file \
    xz-utils \
    python3 \
    python3-pip \
    python3-venv \
    perl \
    sudo \
    pkg-config \
    cmake \
    ninja-build \
    libgl1-mesa-dev \
    libfontconfig1 \
    libdbus-1-3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir /nix && chown jenkins:jenkins /nix

# Install/Update Golang to the version we need
RUN GOLANG_SHA256="da18191ddb7db8a9339816f3e2b54bdded8047cdc2a5d67059478f8d1595c43f" \
    && GOLANG_TARBALL="go${GOLANG_VERSION}.linux-amd64.tar.gz" \
    && rm -rf /usr/local/go \
    && wget -q "https://dl.google.com/go/${GOLANG_TARBALL}" \
    && echo "${GOLANG_SHA256} ${GOLANG_TARBALL}" | sha256sum -c \
    && tar -C /usr/local -xzf "${GOLANG_TARBALL}" \
    && rm "${GOLANG_TARBALL}" \
    && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Install Go tools as root first, then copy to accessible location
RUN /usr/local/go/bin/go install github.com/go-bindata/go-bindata/v3/go-bindata@latest \
    && /usr/local/go/bin/go install go.uber.org/mock/mockgen@v0.4.0 \
    && /usr/local/go/bin/go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.1 \
    && cp /root/go/bin/* /usr/local/bin/ 2>/dev/null || true

# Configure Qt library path
RUN echo "/opt/qt/${QTVER}/gcc_64/lib" > /etc/ld.so.conf.d/qt.conf \
    && ldconfig

# Create missing Qt Android directory for compatibility
RUN mkdir -p /opt/qt/${QTVER}/android_arm64_v8a/lib/pkgconfig

# Switch to jenkins user for user-specific installations
USER jenkins
WORKDIR /home/jenkins

# Build OpenSSL for Android arm64-v8a
RUN set -e \
    && git clone --depth 1 --branch openssl-3.0.15 https://github.com/openssl/openssl.git \
    && mkdir -p openssl-output/arm64-v8a \
    && cd openssl \
    && echo "Building OpenSSL for arm64-v8a..." \
    && export ANDROID_NDK_HOME=${ANDROID_NDK_ROOT} \
    && export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH \
    && ./Configure android-arm64 \
        -D__ANDROID_API__=21 \
        --prefix=/home/jenkins/openssl-output/arm64-v8a \
        --openssldir=/home/jenkins/openssl-output/arm64-v8a \
        no-shared \
        no-tests \
    && make -j$(($(nproc))) \
    && make install_sw \
    && make clean \
    && echo "OpenSSL build completed"

RUN curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y \
    && /home/jenkins/.nimble/bin/choosenim ${NIM_VERSION}

RUN curl -s https://nixos.org/releases/nix/nix-${NIX_VERSION}/install | sh -s -- --no-daemon

# Install Go tools for jenkins user as well
RUN /usr/local/go/bin/go install github.com/go-bindata/go-bindata/v3/go-bindata@latest \
    && /usr/local/go/bin/go install go.uber.org/mock/mockgen@v0.4.0

# To create system-wide symlinks
USER root

# Create symlinks for Nim tools
RUN ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/nim /usr/local/bin/nim \
    && ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/nimble /usr/local/bin/nimble \
    && ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/choosenim /usr/local/bin/choosenim \
    && chmod 755 /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/* \
    && chown -R root:root /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin

# PATH with all tools
ENV PATH="/opt/qt/${QTVER}/gcc_64/bin:/opt/qt/${QTVER}/android_arm64_v8a/bin:/usr/local/go/bin:/home/jenkins/go/bin:/opt/qt/${QTVER}/gcc_64/libexec:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/home/jenkins/.nix-profile/bin:/usr/local/bin:${PATH}"

# Qt and OpenSSL environment variables
ENV QT_HOST_PATH="/opt/qt/${QTVER}/gcc_64/"
ENV QT_PLUGIN_PATH="/opt/qt/${QTVER}/gcc_64/plugins"
ENV OPENSSL_LIB_DIR="/home/jenkins/openssl-output/arm64-v8a/lib"
ENV OPENSSL_INC_DIR="/home/jenkins/openssl-output/arm64-v8a/include"

# Switch back to jenkins user as default
USER jenkins
WORKDIR /home/jenkins

ENTRYPOINT ["/bin/bash", "-l", "-c"]

LABEL maintainer="status-team"
LABEL source="https://github.com/status-im/status-app"

# =============================================================================
# Stage 5: Mobile Build Stage - extends nim-runtime with mobile specific deps
# =============================================================================
FROM nim-runtime AS mobile-build

ARG QTVER

USER root
WORKDIR /root

ENV PKG_CONFIG_PATH="/opt/qt/${QTVER}/android_arm64_v8a/lib/pkgconfig"
ENV PATH="/opt/qt/${QTVER}/android_arm64_v8a/bin:/opt/qt/${QTVER}/gcc_64/bin:/opt/qt/${QTVER}/gcc_64/libexec:/opt/qt/${QTVER}/android_arm64_v8a/libexec:/opt/android-sdk/emulator:/opt/android-sdk/tools:/opt/android-sdk/tools/bin:/opt/android-sdk/platform-tools:${PATH}"
ENV ARCH=arm64

RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    rsync \
    s3cmd \
    fuse \
    tk-dev \
    llvm \
    extra-cmake-modules \
    gcc-9 \
    g++-9 \
    libsm6 \
    libice6 \
    libbz2-dev \
    libreadline-dev \
    unixodbc-dev \
    libpq-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libnss3 \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-tools \
    gstreamer1.0-alsa \
    libpulse-mainloop-glib0 \
    gstreamer1.0-pulseaudio \
    libgstreamer-plugins-base1.0-0 \
    libxext6 \
    libxrender1 \
    libxcomposite1 \
    libxtst6 \
    libxrandr2 \
    libxcursor1 \
    libxi6 \
    libxcb-randr0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-render0 \
    libxcb-xinerama0 \
    autoconf \
    automake \
    libtool \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add PPA repositories and install additional tools
RUN apt update -yq && apt install -yq software-properties-common \
 && add-apt-repository -y ppa:git-core/ppa \
 && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
 && apt update -yq && apt full-upgrade -yq \
 && update-alternatives \
    --install /usr/bin/gcc gcc /usr/bin/gcc-9 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-9 \
 && apt-get -qq clean

ARG GRADLE_VERSION=8.11.1
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -O /tmp/gradle.zip \
 && unzip -q /tmp/gradle.zip -d /opt \
 && ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle \
 && rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH="/opt/gradle/bin:/root/go/bin:${PATH}"

LABEL description="Build image for the Status Android APK."
