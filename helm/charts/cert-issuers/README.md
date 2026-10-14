# cert-issuers chart

Creates the cert-manager `ClusterIssuer`s. For now that is `homelab-ca`, which signs certificates with a local CA. Install it after [`cert-manager`](../cert-manager/README.md).

## Local CA

- `scripts/install.sh` creates the CA once in `./.local/homelab-ca/` (`ca.crt`, `ca.key`; ignored by Git, keep the key private; override with `HOMELAB_CA_DIR`). All clusters share it, so clients trust it only once.
- On macOS the script adds `ca.crt` to the System keychain as a trusted root (asks for your password). Safari, Chrome, and Firefox use it. Other clients must import `ca.crt` themselves.
- The CA is only valid for `homelab.com` and `home.arpa` (name constraints). Other domains need a new CA.
- The script creates the `homelab-ca` Secret if it is missing and warns if the cluster has a different CA.

Remove the trust: `sudo security delete-certificate -c "<CA name>" /Library/Keychains/System.keychain` (name: `openssl x509 -noout -subject -in .local/homelab-ca/ca.crt`).

## Install

From the repository root:

```sh
helm/charts/cert-issuers/scripts/install.sh --ca-only   # only create and trust the CA
helm/charts/cert-issuers/scripts/install.sh --wait      # Secret and ClusterIssuer
```

## Values

| Value | Default | Purpose |
|---|---|---|
| `namespace` | `hlab-platform` | cert-manager's namespace, where the CA Secret lives. |
| `clusterIssuer.name` | `homelab-ca` | Name for the `cert-manager.io/cluster-issuer` annotation. |
| `defaultSecrets.ca` | `homelab-ca` (`tls.crt`, `tls.key`) | CA Secret. |

Later (work in progress): public certificates need an owned domain and an ACME issuer (Let's Encrypt, DNS-01).
