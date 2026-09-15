FROM harbor.status.im/status-im/status-desktop-build:1.0.13-qt6.11.0

USER root

RUN apt-get update && apt-get install -yq --no-install-recommends --fix-missing \
    sudo \
    curl wget gnupg ca-certificates lsb-release python3-pip python3-venv

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg \
&& gpg --no-default-keyring --keyring /etc/apt/keyrings/docker.gpg --fingerprint \
      | grep -q "9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88" \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null \
&& apt-get update && apt-get install -y \
    docker-ce-cli docker-compose-plugin \
    mesa-common-dev libglu1-mesa-dev libpcsclite-dev \
    xvfb fluxbox libxft-dev xclip xsel nautilus \
    tesseract-ocr libzbar-dev libopenjp2-7 \
    ruby-dev ruby-bundler leiningen ghp-import git-lfs \
    librocksdb-dev libfuse2 \
    libpython3-dev \
    pcscd \
&& apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 999 docker && usermod -aG docker jenkins

# Node.js for the WalletConnect e2e dApp (npm ci + node runtime).
ARG NODE_VERSION=22.23.2
ARG NODE_SHA256=b294a556e639d64338823920e5866c21c02741742d2e1529ee1a225c1ec9252a
RUN NODE_TARBALL="node-v${NODE_VERSION}-linux-x64.tar.gz" \
 && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}" -o "/tmp/${NODE_TARBALL}" \
 && echo "${NODE_SHA256} /tmp/${NODE_TARBALL}" | sha256sum -c - \
 && tar -xzf "/tmp/${NODE_TARBALL}" -C /usr/local --strip-components=1 \
 && rm "/tmp/${NODE_TARBALL}" \
 && node --version && npm --version

USER jenkins

LABEL maintainer="marko@status.im"
LABEL source="https://github.com/status-im/status-app"
LABEL description="Build image for the Status Desktop e2e tests with Squish and Qt."

ENTRYPOINT [""]
