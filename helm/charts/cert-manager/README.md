# cert-manager chart

Installs [cert-manager](https://cert-manager.io/) with its CRDs in `hlab-platform`. It wraps the upstream chart, pinned in `Chart.yaml` and `Chart.lock`. Issuers live in the [`cert-issuers`](../cert-issuers/README.md) chart, because Helm cannot install CRDs and resources of those kinds in one release.

cert-manager issues a certificate for each Ingress with a `cert-manager.io/cluster-issuer` annotation and `spec.tls`, and renews it.

## Install

Installed by the profile after `platform`. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`.

## Values

Upstream values go under `cert-manager:` ([reference](https://artifacthub.io/packages/helm/cert-manager/cert-manager)). This chart enables and keeps the CRDs, turns off Prometheus, and sets small resource requests.
