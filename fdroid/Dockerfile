FROM harbor.status.im/infra/ci-build-containers:linux-base-1.0.1

USER root

# Install Docker CE client (newer than docker.io from apt)
RUN apt-get update && apt-get install -yq --no-install-recommends \
    ca-certificates curl gnupg apksigner \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -yq --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

USER jenkins
