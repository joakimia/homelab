# Helm

- `charts/` holds every chart the homelab can use, one per application or platform component. Some are scaffolds. See [charts/README.md](charts/README.md) for the layout conventions.
- `deployment/<env>/<cluster>/` is a cluster profile. It decides which charts that cluster gets and how. The folder name is the name of the cluster the profile deploys to. Current profile: [dev/local-microk8s-cluster-dev](deployment/dev/local-microk8s-cluster-dev/README.md).

## How a deployment works

1. `charts/<chart>/scripts/install.sh [helm flags]` installs one chart. It creates the Secrets the chart needs (only if missing), then runs `helm upgrade --install`.
2. A profile contains only `deploy-set.json`, `deploy.sh`, `install.sh`, `README.md`, and `<chart>/values.yaml` overlays.
3. `deploy-set.json` lists the releases in order, with Helm flags:

   ```json
   {
     "defaults": { "helmArgs": ["--wait", "--timeout", "10m", "--rollback-on-failure"] },
     "releases": [
       { "chart": "platform" },
       { "chart": "postgres", "helmArgs": ["--timeout", "15m"] }
     ]
   }
   ```

   A release uses `<chart>/values.yaml` in the profile as its overlay when that file exists, or the file set in `"values"`. Per-release `helmArgs` come after the defaults, so they win.
4. The profile's `deploy.sh` runs each chart's `install.sh` with the overlay and flags. It deploys remotely from the Mac by default, or with `--local` on the node. The profile's `install.sh` copies the bundle to the node over SSH and runs `deploy.sh --local` there. Each profile keeps its own scripts, because the flow can differ per cluster.
