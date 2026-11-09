# Argo CD (GitOps)

Argo CD keeps the RKE2 cluster in sync with this repository. It is deployed as two charts, because the profile tooling finds charts in `helm/charts/`:

- [`argo-cd`](../../helm/charts/argo-cd/README.md): Argo CD itself, at `https://argocd.joakimia.dev/` (Cloudflare Access, then `admin`).
- [`argo-cd-apps`](../../helm/charts/argo-cd-apps/README.md): an ApplicationSet that turns the profile's `deploy-set.json` into one Application per chart, with the profile overlay.

```text
merge to main ──▶ GitHub ◀── Argo CD polls (about 3 min) ──▶ helm template + apply ──▶ cluster
```

## Day to day

| Goal | How |
|---|---|
| Change the cluster | Change charts or overlays, open a PR, merge. Argo CD deploys `main`. |
| Try a branch first | Push it, then `helm/deployment/dev/homelab-rke2-cluster-dev/deploy.sh --revision <branch>`. Every push to it syncs. |
| Go back to main | `deploy.sh --revision main`. Do it before the branch is deleted, or the Applications cannot resolve it. |
| Sync now | Refresh the app in the UI, or `kubectl -n hlab-gitops annotate application <app> argocd.argoproj.io/refresh=normal --overwrite`. |

From the Mac, `deploy.sh --revision` needs the API tunnel and the profile kubeconfig:

```sh
ssh -N -L 16443:10.10.10.101:6443 homelab &
export KUBECONFIG=$PWD/.local/homelab-rke2-cluster-dev.kubeconfig   # context mac-via-ssh
```

## Things to know

- **Bootstrap:** the first `deploy.sh` run on a cluster installs everything with Helm and creates the Secrets. Argo CD does not create Secrets.
- **Manual changes are undone** (`selfHeal`). `kubectl edit` is only good for a quick experiment.
- **Nothing is deleted automatically:** prune is off, and the ApplicationSet never deletes Applications. Remove a chart from `deploy-set.json`, then delete its Application and resources by hand.
- **Changes reach pods with a delay:** a mounted ConfigMap (the homepage files) is updated by the kubelet within a minute or two after the sync.
- **A branch pushed seconds before `--revision`** can show "revision not found" for up to 3 minutes, until Argo CD's repository cache refreshes.
