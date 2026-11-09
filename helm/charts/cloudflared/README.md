# cloudflared chart

Runs the Cloudflare Tunnel connector in `hlab-networking`. It opens outbound connections to Cloudflare, and Cloudflare sends requests for the tunnel's hosts through them. No router port or public IP is needed.

The tunnel, its routing rules, DNS, and the Access login are created with Terraform in [`infratructure/cloudflare`](../../../infratructure/cloudflare/README.md). The tunnel sends every `*.<domain>` request to Traefik's HTTPS entrypoint, so a new app only needs an Ingress with a host in that domain.

## Install

Normally installed by the cluster profile's `deploy.sh` after `traefik`. To install it alone:

```sh
TUNNEL_TOKEN="$(tofu -chdir=infratructure/cloudflare/terraform/dev output -raw tunnel_token)" \
  helm/charts/cloudflared/scripts/install.sh --wait
```

## Secrets

`scripts/install.sh` creates `cloudflared-tunnel` (key `token`) if it is missing, from `$TUNNEL_TOKEN` or a hidden prompt. It never overwrites it; to change the token, delete the Secret and run the script again. cloudflared reads it from a file (`TUNNEL_TOKEN_FILE`).

## Values

| Value | Default | Purpose |
|---|---|---|
| `image.tag` | `2026.10.7` | cloudflared release; the image's own updater is off (`NO_AUTOUPDATE`). |
| `replicaCount` | `1` | Connectors; with more, the pods spread over the nodes. |
| `ports.metrics.containerPort` | `2000` | Metrics and the `/ready` endpoint the probes use. |
| `defaultEnv` | token file, metrics address, log level, no autoupdate | cloudflared settings ([flags](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)). |
| `defaultSecrets.tunnel` | `cloudflared-tunnel`, mounted at `/etc/cloudflared/tunnel` | Tunnel token. |

## Templates

`deployment.yaml`.
