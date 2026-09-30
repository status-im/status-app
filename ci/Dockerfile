ARG QT_VERSION="6.11.0"
ARG QT_MODULES="qtwebchannel qtwebview qtwebsockets qt5compat qtmultimedia qtwebengine qtpositioning qtserialport qtshadertools qtimageformats qtscxml qthttpserver"
ARG PCSCLITE_VERSION="2.2.3"
ARG PCSCLITE_SHA256="6e0205a47ec0dd10c000965ee88e08e60c2f7f3ce7280ce0e624915821ea2402"
ARG NIM_VERSION="2.2.10"
ARG NIM_SRC_SHA256="7957b7ed004206bcf10bcc4f3b4744153878e62f2431552a9a8e9d3f40e8d5d5"
ARG CCID_VERSION="1.7.0"
ARG CCID_SHA256="4abe76010a72944e02e8d5d4d60ba665f941891eee2a35f77fd35cebc095e14b"

# Architecture specific values -------------------------------------------------
# TARGETARCH is set by BuildKit, the matching stage is selected below.
FROM ubuntu:24.04 AS arch-amd64

ENV ARCH_UNAME=x86_64 \
    ARCH_TRIPLET=x86_64-linux-gnu \
    QT_HOST=linux \
    QT_ARCH=linux_gcc_64 \
    QT_PLATFORM=gcc_64 \
    GOLANG_ARCH=amd64 \
    GOLANG_SHA256=da18191ddb7db8a9339816f3e2b54bdded8047cdc2a5d67059478f8d1595c43f \
    PROTOC_ARCH=x86_64 \
    PROTOC_SHA256=bc8211ce760bd43ee21ddc145d6d9dbaeeabae205267a79d9054a240e367d4b4 \
    LINUXDEPLOYQT_SHA256=974a87457ed26241b793bed7841978fcdf84158d13220e53833a06515f173b0b

FROM ubuntu:24.04 AS arch-arm64

ENV ARCH_UNAME=aarch64 \
    ARCH_TRIPLET=aarch64-linux-gnu \
    QT_HOST=linux_arm64 \
    QT_ARCH=linux_gcc_arm64 \
    QT_PLATFORM=gcc_arm64 \
    GOLANG_ARCH=arm64 \
    GOLANG_SHA256=fd2bccce882e29369f56c86487663bb78ba7ea9e02188a5b0269303a0c3d33ab \
    PROTOC_ARCH=aarch_64 \
    PROTOC_SHA256=4a00ec5e256d20a3deadd9e77d56da0ac04c72367c3c959f6d08e110a368400a \
    LINUXDEPLOYQT_SHA256=986d52d855a8c0ea8c51564807e8fb6af3466426d29224093c040b56ba244df3

FROM arch-${TARGETARCH} AS arch

# QT Installation Image --------------------------------------------------------
FROM arch AS qt-install

ARG QT_VERSION QT_MODULES

RUN apt update && apt full-upgrade -y \
 && apt install -y --no-install-recommends sudo python3 python3-venv \
 && apt-get -qq clean

RUN chmod -R 777 /opt

# Install QT
# aqtinstall goes into a venv: pip refuses to touch the system Python on Ubuntu 24.04 (PEP 668).
RUN python3 -m venv /opt/aqt \
 && /opt/aqt/bin/pip install aqtinstall \
 && /opt/aqt/bin/aqt install-qt ${QT_HOST} desktop ${QT_VERSION} ${QT_ARCH} -m ${QT_MODULES} -O /opt/qt --timeout 3000

RUN rm /opt/qt/${QT_VERSION}/${QT_PLATFORM}/plugins/imageformats/libqtiff.so \
       /opt/qt/${QT_VERSION}/${QT_PLATFORM}/lib/cmake/Qt6Gui/Qt6QTiffPlugin*

# PCSC Lite Build Image --------------------------------------------------------
FROM arch AS pcsc-build

ARG PCSCLITE_VERSION PCSCLITE_SHA256 CCID_VERSION CCID_SHA256

# To fix: https://github.com/status-im/status-app/issues/16768
# https://blog.apdu.fr/posts/2024/05/pcsc-lite-now-uses-meson-build-tool/
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential debhelper dpkg-dev libudev-dev libusb-1.0-0-dev pkg-config flex libsystemd-dev check git wget \
    meson ninja-build libglib2.0-dev libexpat1-dev python3-pip \
 && apt-get -qq clean

RUN wget -q "https://github.com/LudovicRousseau/PCSC/archive/refs/tags/${PCSCLITE_VERSION}.tar.gz" -O /tmp/pcsc.tar.gz \
 && echo "${PCSCLITE_SHA256} /tmp/pcsc.tar.gz" | sha256sum -c \
 && mkdir /pcsc \
 && tar -xzf /tmp/pcsc.tar.gz -C /pcsc --strip-components=1

WORKDIR /pcsc

RUN meson setup builddir -Dpolkit=false -Dlibsystemd=false -Dserial=false \
    -Dipcdir=/tmp/pcscd/run -Dusbdropdir=/tmp/pcscd/drivers \
    -Dlibdir=lib/${ARCH_TRIPLET}
RUN cd builddir && ninja && ninja install
RUN cp builddir/pcsclite.h src/PCSC

RUN wget -q "https://github.com/LudovicRousseau/CCID/archive/refs/tags/${CCID_VERSION}.tar.gz" -O /tmp/ccid.tar.gz \
 && echo "${CCID_SHA256} /tmp/ccid.tar.gz" | sha256sum -c \
 && mkdir /ccid \
 && tar -xzf /tmp/ccid.tar.gz -C /ccid --strip-components=1

WORKDIR /ccid
ENV PKG_CONFIG_PATH=/usr/local/lib/${ARCH_TRIPLET}/pkgconfig:/usr/local/lib/pkgconfig
RUN meson setup builddir -Dserial=false -Dudev-rules=false
RUN cd builddir && ninja && ninja install

# Build Image ------------------------------------------------------------------
FROM arch

ARG QT_VERSION PCSCLITE_VERSION NIM_VERSION NIM_SRC_SHA256

# Adapted from a12e/docker-qt by Aurélien Brooke

ENV DEBIAN_FRONTEND=noninteractive \
    QMAKESPEC=linux-g++ \
    QT_PATH=/opt/qt \
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
    gnupg2 openssh-client ca-certificates locales sudo jq curl wget fuse3 libfuse2t64 libminizip1t64 s3cmd file unzip llvm tk-dev xz-utils netbase \
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
    libusb-1.0-0 \
 && apt-get -qq clean

# Install PCSC Lite
COPY --from=pcsc-build /pcsc/builddir/pcscd   /usr/local/sbin/
COPY --from=pcsc-build /pcsc/src/PCSC /usr/local/include/PCSC/
COPY --from=pcsc-build /pcsc/builddir/meson-private/libpcsclite.pc /usr/local/lib/${ARCH_TRIPLET}/pkgconfig/
COPY --from=pcsc-build /pcsc/builddir/libpcsclite_real.so.1 /pcsc/builddir/libpcsclite_real.so \
                       /pcsc/builddir/libpcsclite.so.1      /pcsc/builddir/libpcsclite.so \
                       /pcsc/builddir/libpcscspy.so.0       /pcsc/builddir/libpcscspy.so \
                       /usr/local/lib/${ARCH_TRIPLET}/
COPY --from=pcsc-build /tmp/pcscd/drivers /usr/local/lib/pcsc/drivers

# Install linuxdeployqt
RUN mkdir -p /usr/local/bin \
 && curl -Lo/usr/local/bin/linuxdeployqt "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-${ARCH_UNAME}.AppImage" \
 && echo "${LINUXDEPLOYQT_SHA256} /usr/local/bin/linuxdeployqt" | sha256sum -c \
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
RUN CMAKE_INSTALLER="cmake-3.22.1-linux-${ARCH_UNAME}.sh" \
 && wget "https://github.com/Kitware/CMake/releases/download/v3.22.1/${CMAKE_INSTALLER}" \
 && chmod +x "${CMAKE_INSTALLER}" \
 && sudo mkdir /opt/cmake \
 && sudo sh "${CMAKE_INSTALLER}" --prefix=/opt/cmake --exclude-subdir --skip-license \
 && rm -f "${CMAKE_INSTALLER}"
ENV PATH="/opt/cmake/bin:${PATH}"

# Installing Golang
RUN GOLANG_TARBALL="go1.24.7.linux-${GOLANG_ARCH}.tar.gz" \
 && wget -q "https://dl.google.com/go/${GOLANG_TARBALL}" \
 && echo "${GOLANG_SHA256} ${GOLANG_TARBALL}" | sha256sum -c \
 && sudo tar -C /usr/local -xzf "${GOLANG_TARBALL}" \
 && rm "${GOLANG_TARBALL}" \
 && sudo ln -s /usr/local/go/bin/go /usr/local/bin

# Install Protoc
RUN PROTOC_TARBALL="protoc-36.0-linux-${PROTOC_ARCH}.zip" \
 && wget -q -L  "https://github.com/protocolbuffers/protobuf/releases/download/v36.0/${PROTOC_TARBALL}" \
 && echo "${PROTOC_SHA256} ${PROTOC_TARBALL}" | sha256sum -c \
 && sudo unzip -d /usr/local "${PROTOC_TARBALL}" \
 && rm "${PROTOC_TARBALL}"

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

# Nim is built from the source tarball, there are no official aarch64 binaries.
USER root

RUN wget -q "https://nim-lang.org/download/nim-${NIM_VERSION}.tar.xz" -O /tmp/nim.tar.xz \
 && echo "${NIM_SRC_SHA256} /tmp/nim.tar.xz" | sha256sum -c \
 && mkdir -p /opt/nim \
 && tar -xJf /tmp/nim.tar.xz -C /opt/nim --strip-components=1 \
 && rm /tmp/nim.tar.xz \
 && cd /opt/nim \
 && sh build.sh \
 && bin/nim c --noNimblePath --skipUserCfg --skipParentCfg --hints:off koch \
 && ./koch boot -d:release --skipUserCfg --skipParentCfg --hints:off \
 && ./koch nimble \
 && ln -sf /opt/nim/bin/nim /usr/local/bin/nim \
 && ln -sf /opt/nim/bin/nimble /usr/local/bin/nimble

USER jenkins

# Access to tools installed by Nimble.
ENV PATH="/home/jenkins/.nimble/bin:${PATH}"

LABEL maintainer="jakub@status.im"
LABEL source="https://github.com/status-im/status-app"
LABEL description="Build image for the Status Desktop client written in Nim."
