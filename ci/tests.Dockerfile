FROM harbor.status.im/status-im/status-desktop-build:1.0.8-qt6.11.0

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

USER jenkins

LABEL maintainer="marko@status.im"
LABEL source="https://github.com/status-im/status-app"
LABEL description="Build image for the Status Desktop e2e tests with Squish and Qt."

ENTRYPOINT [""]
