ARG SOPS_VERSION=3.9.0
ARG TERRAFORM_VERSION=1.9.5

FROM ghcr.io/getsops/sops:v${SOPS_VERSION}-alpine AS sops

FROM alpine/terragrunt:tf${TERRAFORM_VERSION} AS base

COPY --from=sops /usr/local/bin/sops /usr/local/bin/sops