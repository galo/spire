# Build stage
ARG goversion
FROM golang:${goversion} as builder
RUN apt install git mercurial
ADD go.mod /spire/go.mod
ADD proto/spire/go.mod /spire/proto/spire/go.mod
RUN cd /spire && go mod download
ADD . /spire
WORKDIR /spire
RUN make build

# Common base
FROM ubuntu AS spire-base
RUN apt update && apt install dumb-init libtspi-dev -y
RUN mkdir -p /opt/spire/bin

# SPIRE Server
FROM spire-base AS spire-server
COPY --from=builder /spire/bin/spire-server /opt/spire/bin/spire-server
COPY --from=builder /spire/plugins/tpm_attestor_server /opt/spire/bin/tpm_attestor_server

# Add: CA certs for TPM
ADD  etc/certs /opt/spire/.data/certs

WORKDIR /opt/spire
ENTRYPOINT ["/usr/bin/dumb-init", "/opt/spire/bin/spire-server", "run"]
CMD []

# SPIRE Agent
FROM spire-base AS spire-agent
COPY --from=builder /spire/bin/spire-agent /opt/spire/bin/spire-agent
COPY --from=builder /spire/plugins/tpm_attestor_agent /opt/spire/bin/tpm_attestor_agent
# TODO: This is just for testing
COPY --from=builder /spire/plugins/get_tpm_pubhash /opt/spire/bin/get_tpm_pubhash

WORKDIR /opt/spire
ENTRYPOINT ["/usr/bin/dumb-init", "/opt/spire/bin/spire-agent", "run"]
CMD []

# K8S Workload Registrar
FROM spire-base AS k8s-workload-registrar
COPY --from=builder /spire/bin/k8s-workload-registrar /opt/spire/bin/k8s-workload-registrar
WORKDIR /opt/spire
ENTRYPOINT ["/usr/bin/dumb-init", "/opt/spire/bin/k8s-workload-registrar"]
CMD []

# OIDC Discovery Provider
FROM spire-base AS oidc-discovery-provider
COPY --from=builder /spire/bin/oidc-discovery-provider /opt/spire/bin/oidc-discovery-provider
WORKDIR /opt/spire
ENTRYPOINT ["/usr/bin/dumb-init", "/opt/spire/bin/oidc-discovery-provider"]
CMD []
