FROM hub-registre-docker.loto-quebec.com/ubi8:8.6-754
LABEL image.version=$CONSUL_VERSION \
      image.authors="Martial AGBANGLA" \
      name="consul" \
      maintainer="AGBANGLA Martial <amour.martial@gmail.com>" \
      vendor="HashiCorp" \
      version=$CONSUL_VERSION \
      release=$CONSUL_VERSION \
      summary="This image is built for la in loto-quebec network." \
      description="Consul is a datacenter runtime that provides service discovery, configuration, and orchestration."


ENV LQ_CONSUL_node_name=c1
ENV LQ_CONSUL_domain=consul.loto-quebec.ti
ENV LQ_CONSUL_dns_port=53
ENV LQ_CONSUL_datacenter=dc2
ENV LQ_CONSUL_address=10.8.40.155
ENV LQ_CONSUL_peers=10.8.40.152,10.8.40.153,10.8.40.154
ENV LQ_CONSUL_CLUSTER_CA_CERT=%{hiera('consul_ca_cert')}
ENV LQ_CONSUL_CLUSTER_CA_KEY=%{hiera('consul_ca_key')}
ENV LQ_CONSUL_gossip_key=%{hiera('consul_gossip_key')}
ENV LQ_CONSUL_verify_incoming=false
ENV LQ_CONSUL_acls_enabled=true
ENV LQ_CONSUL_acls_default_policy=allow
ENV LQ_CONSUL_agent_token=%{hiera('consul_agent_token_c1')}
ENV CONSUL_ALLOW_PRIVILEGED_PORTS=true

ARG CONSUL_VERSION=1.10.0
ENV SERVER=True
ARG CONSUL_ARCH=amd64
ENV BOOTSTRAT_EXPECT="3"
ENV NODE="consul_s1"
ENV BIND="0.0.0.0"
ENV DATA_DIR="/consul/data"
ENV CONFIG_DIR="/consul/config"

ENV HASHICORP_RELEASES=https://releases.hashicorp.com
RUN set -eux
RUN groupadd consul && \
    adduser --uid 100 --system -g consul consul

RUN mkdir -p /consul/data && \
    mkdir -p /consul/config && \
    chown -R consul /consul && \
    chgrp -R 0 /consul && chmod -R g+rwX /consul

COPY files/* /etc/pki/ca-trust/
RUN ls /etc/pki/ca-trust/
RUN update-ca-trust

RUN sed --in-place --expression '/\(sslverify=\).*/{s//\1False/;:a;n;ba;q}' --expression '$asslverify=False' /etc/dnf/dnf.conf \
  && dnf clean   --assumeyes --quiet --disableplugin=subscription-manager all && rm --recursive --force /var/cache/yum \
  && dnf update  --assumeyes --quiet --disableplugin=subscription-manager
RUN dnf install -y --disableplugin=subscription-manager ca-certificates curl gnupg libcap openssl iputils jq iptables wget unzip tar && \
dnf clean   --assumeyes --quiet --disableplugin=subscription-manager all && rm --recursive --force /var/cache/yum

RUN mkdir -p /tmp/build && \
    cd /tmp/build && \
    wget --no-check-certificate ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${CONSUL_ARCH}.zip && \
    ls && \
    unzip -d /tmp/build consul_${CONSUL_VERSION}_linux_${CONSUL_ARCH}.zip && \
    cp /tmp/build/consul /bin/consul && \
    if [ -f /tmp/build/EULA.txt ]; then mkdir -p /usr/share/doc/consul; mv /tmp/build/EULA.txt /usr/share/doc/consul/EULA.txt; fi && \
    if [ -f /tmp/build/TermsOfEvaluation.txt ]; then mkdir -p /usr/share/doc/consul; mv /tmp/build/TermsOfEvaluation.txt /usr/share/doc/consul/TermsOfEvaluation.txt; fi && \
    cd /tmp && \
    rm -rf /tmp/build && \
    gpgconf --kill all && \
    rm -rf /root/.gnupg && \ 
    consul version

VOLUME /consul/data

# Server RPC is used for communication between Consul clients and servers for internal
# request forwarding.
EXPOSE 8300
# Serf LAN and WAN (WAN is used only by Consul servers) are used for gossip between
# Consul agents. LAN is within the datacenter and WAN is between just the Consul
# servers in all datacenters.
EXPOSE 8301 8301/udp 8302 8302/udp

# HTTP and DNS (both TCP and UDP) are the primary interfaces that applications
# use to interact with Consul.
EXPOSE 8500 8600 8600/udp

COPY files/intro /usr/local/bin/intro
COPY files/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod a+x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# OpenShift by default will run containers with a random user, however their
# scanner requires that containers set a non-root user.
USER 100

# By default you'll get an insecure single-node development server that stores
# everything in RAM, exposes a web UI and HTTP endpoints, and bootstraps itself.
# Don't use this configuration for production.
CMD ["agent", "-dev", "-client", "0.0.0.0"]
