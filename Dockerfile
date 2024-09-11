#
# Build
#

FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder

USER root

WORKDIR /workdir/rhtap-cli

COPY --from=registry.redhat.io/openshift4/ose-cli-rhel9:v4.16 /usr/bin /usr/bin

COPY charts/ ./charts/
COPY cmd/ ./cmd/
COPY pkg/ ./pkg/
COPY scripts/ ./scripts/
COPY vendor/ ./vendor/

COPY config.yaml go.mod go.sum Makefile ./

RUN make GOFLAGS='-buildvcs=false'

#
# Run
#

FROM registry.access.redhat.com/ubi9-minimal:9.4-1227

WORKDIR /rhtap-cli

COPY --from=builder /workdir/rhtap-cli/charts ./charts/
COPY --from=builder /workdir/rhtap-cli/scripts ./scripts/
COPY --from=builder /workdir/rhtap-cli/config.yaml .
COPY --from=builder /usr/bin/oc /usr/bin/oc
COPY --from=builder /usr/bin/kubectl /usr/bin/kubectl

COPY --from=builder /workdir/rhtap-cli/bin/rhtap-cli .

RUN microdnf install shadow-utils && \
    groupadd --gid 1000 -r rhtap-cli && \
    useradd -r -g rhtap-cli -s /sbin/nologin --uid 1000 rhtap-cli && \
    microdnf clean all

USER rhtap-cli

ENTRYPOINT ["/rhtap-cli/rhtap-cli"]
