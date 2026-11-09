# argo-cd-apps chart

One Argo CD `ApplicationSet` that deploys a cluster profile: it reads the profile's `deploy-set.json` from Git and makes one Application per release, from `helm/charts/<chart>` with the overlay `<profile>/<chart>/values.yaml`, into the release's `namespace`. A chart added to `deploy-set.json` on `main` is deployed without running anything.

Applications sync automatically and undo changes made by hand (`selfHeal`). Resources removed from Git are not deleted until `syncPolicy.prune` is turned on. The ApplicationSet never deletes an Application (`create-update`, resources preserved), so removing a chart from `deploy-set.json` leaves it running; delete the Application by hand to stop managing it. They retry while the charts they depend on are not there yet (CRDs, Secrets), so order in `deploy-set.json` matters less than for `deploy.sh`.

## Install

Installed by the profile's `deploy.sh` after [`argo-cd`](../argo-cd/README.md). This chart is excluded from the ApplicationSet, so Argo CD never changes its own revision.

## Deploy a branch

```sh
helm/deployment/dev/homelab-rke2-cluster-dev/deploy.sh --revision my-branch   # push the branch first
helm/deployment/dev/homelab-rke2-cluster-dev/deploy.sh --revision main        # back to main
```

Every Application then follows that branch. A full `deploy.sh` run also sets the revision back to `main`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `profilePath` | required | Profile folder, e.g. `helm/deployment/dev/homelab-rke2-cluster-dev`. |
| `repoURL` / `revision` | this repository / `main` | Where Argo CD reads the charts and profile. |
| `exclude` | `[argo-cd-apps]` | Releases in `deploy-set.json` that Argo CD does not manage. |
| `syncPolicy.selfHeal` / `prune` | `true` / `false` | Undo manual changes / delete resources removed from Git. |

## Templates

`applicationset.yaml`.
