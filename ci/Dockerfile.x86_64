ARG QT_VERSION="6.11.0"
ARG QT_MODULES="qtwebchannel qtwebview qtwebsockets qt5compat qtmultimedia qtwebengine qtpositioning qtserialport qtshadertools qtimageformats qtscxml qthttpserver"
ARG LINUXDEPLOYQT_VERSION="20250615-0393b84"
ARG PCSCLITE_VERSION="2.2.3"
ARG NIM_VERSION="2.2.4"

# QT Installation Image --------------------------------------------------------
FROM ubuntu:22.04 AS qt-install

ARG QT_VERSION QT_MODULES

RUN apt update && apt full-upgrade -y \
 && apt install -y --no-install-recommends sudo python3 python3-pip python3-dev build-essential \
 && apt-get -qq clean

RUN chmod -R 777 /opt

# Install QT
RUN python3 -m pip install setuptools \
 && python3 -m pip install -U pip \
 && python3 -m pip install aqtinstall \
 && python3 -m aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 -m ${QT_MODULES} -O /opt/qt --timeout 3000

# PCSC Lite Build Image --------------------------------------------------------
FROM ubuntu:22.04 AS pcsc-build

ARG PCSCLITE_VERSION

# To fix: https://github.com/status-im/status-app/issues/16768
# https://blog.apdu.fr/posts/2024/05/pcsc-lite-now-uses-meson-build-tool/
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential debhelper dpkg-dev libudev-dev libusb-1.0-0-dev pkg-config flex libsystemd-dev check git wget \
    meson ninja-build libglib2.0-dev libexpat1-dev python3-pip \
 && apt-get -qq clean

RUN wget https://pcsclite.apdu.fr/files/pcsc-lite-${PCSCLITE_VERSION}.tar.xz -O /tmp/pcsc.tar.xz
RUN mkdir /pcsc
RUN tar -xJf /tmp/pcsc.tar.xz -C /pcsc --strip-components=1

WORKDIR /pcsc

RUN meson setup builddir -Dpolkit=false -Dlibsystemd=false -Dserial=false -Dipcdir=/tmp/pcscd/run
RUN cd builddir && ninja
RUN cp builddir/pcsclite.h src/PCSC

# Build Image ------------------------------------------------------------------
FROM ubuntu:22.04

ARG QT_VERSION LINUXDEPLOYQT_VERSION PCSCLITE_VERSION NIM_VERSION

# Adapted from a12e/docker-qt by Aurélien Brooke

ENV DEBIAN_FRONTEND=noninteractive \
    QMAKESPEC=linux-g++ \
    QT_PATH=/opt/qt \
    QT_PLATFORM=gcc_64 \
    QT_VERSION=$QT_VERSION

ENV QTDIR=${QT_PATH}/${QT_VERSION}/${QT_PLATFORM}
# Since QT6 rcc is in libexec folder.
ENV PATH=${QTDIR}/bin:${QTDIR}/libexec:$PATH

ENV LD_LIBRARY_PATH=${QTDIR}/lib:${LD_LIBRARY_PATH}

# Install dependencies
RUN apt update -yq && apt install -yq software-properties-common \
 && add-apt-repository -y ppa:git-core/ppa \
 && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
 && apt update -yq && apt full-upgrade -yq && apt install -yq --no-install-recommends --fix-missing  \
    gnupg2 openssh-client ca-certificates locales sudo jq curl wget fuse s3cmd file unzip llvm tk-dev xz-utils netbase \
    git make build-essential pkg-config extra-cmake-modules \
    flatpak flatpak-builder elfutils appstream \
    libgl1-mesa-dev libsm6 libice6 libfontconfig1 libdbus-1-3 libssl-dev libz-dev \
    zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev unixodbc-dev libpq-dev \
    libncurses5-dev libncursesw5-dev libnss3 \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa libpulse-mainloop-glib0 \
    gstreamer1.0-pulseaudio libgstreamer-plugins-base1.0-0 \
    libxext6 libxrender1 libxkbcommon-dev libxkbcommon-x11-dev libxcomposite1 libxtst6 \
    libxrandr2 libxcursor1 libxi6 libxcb-randr0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-render-util0 libxcb-shape0 libxcb-render0 libxcb-xinerama0 \
    autoconf automake libtool gcc-11 g++-11 \
    libxslt1.1 libxslt1-dev libxkbfile1 libxkbfile-dev \
    libxcb-cursor0 libxcb-cursor-dev \
    libatk1.0-0 libatk1.0-dev \
    libcups2 libcups2-dev \
    libgtk-3-0 libgtk-3-dev \
    libgdk-pixbuf-2.0-0 libgdk-pixbuf2.0-dev \
 && apt-get -qq clean

# Install PCSC Lite
COPY --from=pcsc-build /pcsc/builddir/pcscd   /usr/local/sbin/
COPY --from=pcsc-build /pcsc/src/PCSC /usr/local/include/
COPY --from=pcsc-build /pcsc/builddir/meson-private/libpcsclite.pc /usr/local/lib/x86_64-linux-gnu/pkgconfig/
COPY --from=pcsc-build /pcsc/builddir/libpcsclite_real.so.1 /pcsc/builddir/libpcsclite_real.so \
                       /pcsc/builddir/libpcsclite.so.1      /pcsc/builddir/libpcsclite.so \
                       /pcsc/builddir/libpcscspy.so.0       /pcsc/builddir/libpcscspy.so \
                       /usr/local/lib/x86_64-linux-gnu/

# Install linuxdeployqt
# built from https://github.com/probonopd/linuxdeployqt/commit/0393b84
RUN mkdir -p /usr/local/bin \
 && curl -Lo/usr/local/bin/linuxdeployqt "https://status-misc.ams3.digitaloceanspaces.com/desktop/linuxdeployqt-${LINUXDEPLOYQT_VERSION}-x86_64.AppImage" \
 && chmod a+x /usr/local/bin/linuxdeployqt

# Reconfigure locale
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy QT toolchain
RUN chmod -R 777 /opt && mkdir -p /opt/qt/$QT_VERSION
COPY --from=qt-install /opt/qt/$QT_VERSION /opt/qt/$QT_VERSION/.

# Fix LetsEncrypt X3 root certificate expliration
RUN sudo sed -i 's#\(mozilla/DST_Root_CA_X3.crt\)#!\1#' /etc/ca-certificates.conf \
 && sudo dpkg-reconfigure -fnoninteractive ca-certificates

# CMake 3.16 or higher is required
RUN wget https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-x86_64.sh \
 && chmod +x cmake-3.22.1-linux-x86_64.sh \
 && sudo mkdir /opt/cmake \
 && sudo sh cmake-3.22.1-linux-x86_64.sh --prefix=/opt/cmake --exclude-subdir --skip-license \
 && rm -f cmake-3.22.1-linux-x86_64.sh
ENV PATH="/opt/cmake/bin:${PATH}"

# Installing Golang
RUN GOLANG_SHA256="da18191ddb7db8a9339816f3e2b54bdded8047cdc2a5d67059478f8d1595c43f" \
 && GOLANG_TARBALL="go1.24.7.linux-amd64.tar.gz" \
 && wget -q "https://dl.google.com/go/${GOLANG_TARBALL}" \
 && echo "${GOLANG_SHA256} ${GOLANG_TARBALL}" | sha256sum -c \
 && sudo tar -C /usr/local -xzf "${GOLANG_TARBALL}" \
 && rm "${GOLANG_TARBALL}" \
 && sudo ln -s /usr/local/go/bin/go /usr/local/bin

# Install Protoc
RUN PROTOC_SHA256="75d8a9d7a2c42566e46411750d589c51276242d8b6247a5724bac0f9283e05a8" \
 && PROTOC_TARBALL="protoc-3.20.0-linux-x86_64.zip" \
 && wget -q -L  "https://github.com/protocolbuffers/protobuf/releases/download/v3.20.0/${PROTOC_TARBALL}" \
 && echo "${PROTOC_SHA256} ${PROTOC_TARBALL}" | sha256sum -c \
 && sudo unzip -d /usr/local "${PROTOC_TARBALL}" \
 && rm "${PROTOC_TARBALL}"

# Install Protoc-deg-go
RUN PROTOC_GEN_SHA256="0b2c257938a8cd9ba3506bbdbbaad45e51245b6f9e0743035ade7acf746c6be7" \
 && PROTOC_GEN_TARBALL="protoc-gen-go.v1.34.1.linux.amd64.tar.gz" \
 && wget -q -L "https://github.com/protocolbuffers/protobuf-go/releases/download/v1.34.1/${PROTOC_GEN_TARBALL}" \
 && echo "${PROTOC_GEN_SHA256} ${PROTOC_GEN_TARBALL}" | sha256sum -c \
 && sudo tar -C /usr/local/bin -xzf "${PROTOC_GEN_TARBALL}" \
 && rm "${PROTOC_GEN_TARBALL}"

# Create Nix directory as root.
RUN mkdir /nix && chown 1001:1001 /nix

# Jenkins user needs a specific UID/GID to work
RUN sudo groupadd -g 1001 jenkins \
 && sudo useradd --create-home -u 1001 -g 1001 jenkins
USER jenkins
ENV HOME="/home/jenkins"

# Setup Flatpak for jenkins user (freedesktop runtime - we bundle Qt from /opt/qt)
RUN flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo \
 && flatpak install --user -y flathub org.freedesktop.Platform//24.08 \
 && flatpak install --user -y flathub org.freedesktop.Sdk//24.08

 # Rust is needed for nwaku builds
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="${HOME}/.cargo/bin:${PATH}"

# Access to tools installed by Go.
ENV PATH="${HOME}/go/bin:${PATH}"

# Nix for jenkins user to build status-go.
RUN curl -s https://nixos.org/releases/nix/nix-2.24.11/install | sh -s -- --no-daemon
# for nix-shell to work
ENV PATH="/home/jenkins/.nix-profile/bin:${PATH}"

# Nim
RUN curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y \
 && /home/jenkins/.nimble/bin/choosenim ${NIM_VERSION}
ENV PATH="/home/jenkins/.nimble/bin:${PATH}"

# Switch to root to create system-wide symlinks for Nim tools
USER root

RUN ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/nim /usr/local/bin/nim \
 && ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/nimble /usr/local/bin/nimble \
 && ln -sf /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/choosenim /usr/local/bin/choosenim \
 && chmod 755 /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin/* \
 && chown -R root:root /home/jenkins/.choosenim/toolchains/nim-${NIM_VERSION}/bin

USER jenkins

LABEL maintainer="jakub@status.im"
LABEL source="https://github.com/status-im/status-app"
LABEL description="Build image for the Status Desktop client written in Nim."
