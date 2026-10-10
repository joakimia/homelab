#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CHARTS="$REPO_ROOT/helm/charts"
DB_NAMESPACE=hlab-database
APP_NAMESPACE=hlab-frontend-apps
DB_USER=homelab
DB_NAME=homelab
PGADMIN_EMAIL="${PGADMIN_DEFAULT_EMAIL:-admin@homelab.com}"

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done
kubectl get nodes >/dev/null

echo "Installing shared namespaces and network policies"
"$CHARTS/platform/scripts/install.sh" --wait --timeout 5m

if ! kubectl get secret postgres-credentials -n "$DB_NAMESPACE" >/dev/null 2>&1; then
  DB_PASSWORD="$(openssl rand -hex 24)"
  kubectl create secret generic postgres-credentials -n "$DB_NAMESPACE" \
    --from-literal=POSTGRES_DB="$DB_NAME" \
    --from-literal=POSTGRES_USER="$DB_USER" \
    --from-literal=POSTGRES_PASSWORD="$DB_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "Created PostgreSQL credentials Secret (user: $DB_USER, database: $DB_NAME)."
  unset DB_PASSWORD
else
  echo "Reusing PostgreSQL credentials Secret."
fi

if ! kubectl get secret pgadmin-credentials -n "$APP_NAMESPACE" >/dev/null 2>&1; then
  PGADMIN_PASSWORD="$(openssl rand -hex 24)"
  kubectl create secret generic pgadmin-credentials -n "$APP_NAMESPACE" \
    --from-literal=PGADMIN_DEFAULT_EMAIL="$PGADMIN_EMAIL" \
    --from-literal=PGADMIN_DEFAULT_PASSWORD="$PGADMIN_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "Created pgAdmin login Secret. Initial login: $PGADMIN_EMAIL / $PGADMIN_PASSWORD"
  unset PGADMIN_PASSWORD
else
  echo "Reusing pgAdmin credentials Secret."
fi

echo "Installing Traefik"
"$CHARTS/traefik/scripts/install.sh" --wait --timeout 5m
echo "Installing PostgreSQL and PgBouncer"
"$CHARTS/postgres/scripts/install.sh" --wait --timeout 5m
kubectl rollout status statefulset/postgres -n "$DB_NAMESPACE" --timeout=300s
"$CHARTS/pgbouncer/scripts/install.sh" --wait --timeout 5m
kubectl rollout status deployment/pgbouncer -n "$DB_NAMESPACE" --timeout=300s
echo "Installing pgAdmin and the homepage"
"$CHARTS/pgadmin/scripts/install.sh" --wait --timeout 5m
kubectl rollout status deployment/pgadmin -n "$APP_NAMESPACE" --timeout=300s
"$CHARTS/homepage/scripts/install.sh" --wait --timeout 5m
kubectl rollout status deployment/homepage -n "$APP_NAMESPACE" --timeout=300s

echo
echo "Deployed releases:"
helm list -A
echo
echo "Ingresses:"
kubectl get ingress -A
echo
echo "Set Mac DNS or /etc/hosts for pgadmin.homelab.com and homepage.homelab.com to a Traefik node IP."
echo "For a temporary curl check without changing DNS: curl --resolve homepage.homelab.com:80:<NODE-IP> http://homepage.homelab.com/"
