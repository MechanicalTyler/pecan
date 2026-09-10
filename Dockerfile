ARG BASE_IMAGE=node:24-bookworm-slim
FROM ${BASE_IMAGE}

ARG EXTRA_PACKAGES=""
ARG PECAN_USER=pecan
ARG PECAN_HOME=/home/pecan

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash ca-certificates git ripgrep ${EXTRA_PACKAGES} && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

RUN useradd -m -d ${PECAN_HOME} ${PECAN_USER}

COPY scripts/run-hooks.sh /usr/local/bin/pecan-run-hooks.sh
COPY hooks.d/build.d/ /tmp/hooks.d/build.d/
RUN chmod +x /usr/local/bin/pecan-run-hooks.sh && \
    /usr/local/bin/pecan-run-hooks.sh /tmp/hooks.d/build.d && \
    rm -rf /tmp/hooks.d

USER ${PECAN_USER}
WORKDIR ${PECAN_HOME}

ENTRYPOINT ["pi"]
