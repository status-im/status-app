# The suite's CI image (ci/tests.Dockerfile) plus the one tool the stand-in needs.
ARG BASE_IMAGE=status-e2e-tests
FROM ${BASE_IMAGE}

USER root
# nativeMouseClick: Squish clicks through the operating system; the stand-in uses xdotool.
RUN apt-get update && apt-get install -y --no-install-recommends xdotool \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
USER jenkins
