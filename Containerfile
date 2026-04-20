# CheckMK Agent Runtime Image
FROM docker.io/rockylinux:9-minimal

ENV CHECKMK_VERSION=2.4.0p26
ENV CHECKMK_SERVER=https://monitor.nethlab.it/monitoring

# Install base packages
RUN set -e \
    && microdnf install -y \
        python3 \
        git \
        socat \
        curl \
    && microdnf clean all

# Download and install CheckMK agent from Nethesis server
RUN set -e \
    && curl -fsSL ${CHECKMK_SERVER}/check_mk/agents/check-mk-agent-${CHECKMK_VERSION}-1.noarch.rpm \
        -o /tmp/check-mk-agent.rpm \
    && rpm -ivh /tmp/check-mk-agent.rpm \
    && rm -f /tmp/check-mk-agent.rpm

# Clone checkmk-tools repository and deploy NS8 scripts
RUN set -e \
    && git clone https://github.com/nethesis/checkmk-tools.git /opt/checkmk-tools \
    && mkdir -p /usr/lib/check_mk_agent/local \
    && for script in /opt/checkmk-tools/script-check-ns8/full/*.py; do \
        base=$(basename "$script" .py); \
        cp "$script" "/usr/lib/check_mk_agent/local/$base"; \
        chmod +x "/usr/lib/check_mk_agent/local/$base"; \
    done

# Configure socat entrypoint for CheckMK agent
RUN echo '#!/bin/bash' > /entrypoint.sh \
    && echo 'exec socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:/usr/bin/check_mk_agent' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
