# cert-issuers chart

Creates the cert-manager `ClusterIssuer`s: `homelab-ca`, which signs certificates with a local CA, and, with `acme.enabled`, `letsencrypt` and `letsencrypt-staging`. Install it after [`cert-manager`](../cert-manager/README.md).

## Local CA

- `scripts/install.sh` creates the CA once in `./.local/homelab-ca/` (`ca.crt`, `ca.key`; ignored by Git, keep the key private; override with `HOMELAB_CA_DIR`). All clusters share it, so clients trust it only once.
- On macOS the script adds `ca.crt` to the System keychain as a trusted root (asks for your password). Safari, Chrome, and Firefox use it. Other clients must import `ca.crt` themselves.
- The CA is only valid for `homelab.com` and `home.arpa` (name constraints). Other domains need a new CA.
- The script creates the `homelab-ca` Secret if it is missing and warns if the cluster has a different CA.

Remove the trust: `sudo security delete-certificate -c "<CA name>" /Library/Keychains/System.keychain` (name: `openssl x509 -noout -subject -in .local/homelab-ca/ca.crt`).

## Let's Encrypt

With `acme.enabled: true` (the RKE2 profile), each name in `acme.issuers` becomes an ACME ClusterIssuer that proves ownership with a DNS-01 record in Cloudflare. It works for hosts the internet cannot reach. The Cloudflare token can only edit DNS in the zone; Terraform creates it (`tofu output -raw cert_manager_api_token` in [`infratructure/cloudflare`](../../../infratructure/cloudflare/README.md)). `scripts/install.sh` stores it in the `cloudflare-api-token` Secret if missing, from `$CLOUDFLARE_DNS_API_TOKEN` or a hidden prompt.

A certificate stuck on a failed order (`kubectl get order -A` shows `errored`) waits up to an hour before cert-manager retries, and a recreated Certificate picks up the same failed request. If no TLS Secret exists yet, delete the order, its CertificateRequest, and the Certificate; the Ingress recreates it at once.

Try a new host with `letsencrypt-staging` first: production has rate limits (50 certificates per domain per week), staging does not, but browsers do not trust its certificates.

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
| `acme.enabled` | `false` | Add the Let's Encrypt ClusterIssuers. |
| `acme.issuers` | `letsencrypt`, `letsencrypt-staging` | ClusterIssuer name: ACME directory URL. |
| `defaultSecrets.ca` | `homelab-ca` (`tls.crt`, `tls.key`) | CA Secret. |
| `defaultSecrets.cloudflare` | `cloudflare-api-token` (`api-token`) | Cloudflare API token for DNS-01 (with `acme.enabled`). |
