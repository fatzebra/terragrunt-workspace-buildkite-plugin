FROM ghcr.io/getsops/sops:v3.9.0-alpine AS sops

FROM alpine/terragrunt AS base

COPY --from=sops /usr/local/bin/sops /usr/local/bin/sops