#!/bin/bash

# -------------------------------
# Configurable Variables
# -------------------------------

# IP and Domain
BASE_DOMAIN="192.168.200.165.nip.io"
GITEA_HOST="gitea.ui"
GITEA_URL="http://$GITEA_HOST:31080"

# Gitea Credentials
GITEA_USER="gitea"
GITEA_PASS="redhat123"

# NodePort Config
API_PORT=32001
CLI_ARTIFACTS_PORT=32002
AGENT_PORT=32003
UI_PORT=32004
KEYCLOAK_PORT=32005

# Helm Chart Versions
FLIGHTCTL_VERSION="0.7.1"

# Tekton URLs
TEKTON_PIPELINE_URL="https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
TEKTON_DASHBOARD_URL="https://storage.googleapis.com/tekton-releases/dashboard/latest/release-full.yaml"
TEKTON_GIT_CLONE_TASK_URL="https://api.hub.tekton.dev/v1/resource/tekton/task/git-clone/0.9/raw"
TEKTON_TRIGGERS_URL="https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml"
TEKTON_INTERCEPTORS_URL="https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml"

# Repository to import
REPO_CLONE_URL="https://github.com/kubealex/devconf.cz-bootc-keynote"
REPO_NAME="devconf.cz-bootc-keynote"

# -------------------------------
# Install KubeVirt
# -------------------------------

export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
echo "Installing KubeVirt version $VERSION"
kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml"
kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml"
kubectl apply -f https://raw.githubusercontent.com/kubevirt-manager/kubevirt-manager/main/kubernetes/bundled.yaml

# -------------------------------
# Install CDI
# -------------------------------

export TAG=$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)
export VERSION=$(echo ${TAG##*/})
echo "Installing CDI version $VERSION"
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml

# -------------------------------
# Install Tekton
# -------------------------------

kubectl apply -f $TEKTON_PIPELINE_URL
kubectl apply -f $TEKTON_DASHBOARD_URL
kubectl apply -f $TEKTON_GIT_CLONE_TASK_URL
kubectl apply -f $TEKTON_TRIGGERS_URL
kubectl apply -f $TEKTON_INTERCEPTORS_URL

# -------------------------------
# Install FlightCtl
# -------------------------------

helm upgrade --install flightctl ./deploy/helm/flightctl/ \
  --namespace flightctl --create-namespace \
  --version=$FLIGHTCTL_VERSION \
  --set global.exposeServicesMethod=nodePort \
  --set kv.fsGroup=1001 \
  --set db.fsGroup=26 \
  --set keycloak.db.fsGroup=26 \
  --set global.nodePorts.api=$API_PORT \
  --set global.nodePorts.cliArtifacts=$CLI_ARTIFACTS_PORT \
  --set global.nodePorts.agent=$AGENT_PORT \
  --set global.nodePorts.ui=$UI_PORT \
  --set global.nodePorts.keycloak=$KEYCLOAK_PORT \
  --set "global.baseDomain=$BASE_DOMAIN"

# -------------------------------
# Install Gitea
# -------------------------------

helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea --create-namespace \
  --set postgresql-ha.enabled=false \
  --set postgresql.enabled=true \
  --set gitea.admin.username="$GITEA_USER" \
  --set gitea.admin.password="$GITEA_PASS" \
  --set gitea.config.webhook.ALLOWED_HOST_LIST="*" \
  --set gitea.config.webhook.SKIP_TLS_VERIFY=true \
  --set gitea.config.server.ROOT_URL="$GITEA_URL" \
  --set ingress.enabled=true \
  --set "ingress.hosts[0].host=$GITEA_HOST" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"

# -------------------------------
# Apply Custom Resources
# -------------------------------

kubectl apply -f tekton/lab-ingress.yml
kubectl apply -f tekton/tekton-tasks.yml
kubectl apply -f tekton/tekton-pipelines.yml
kubectl apply -f tekton/tekton-triggers.yml

# -------------------------------
# Gitea Token and Repo Import
# -------------------------------

echo "Generating Gitea token..."
auth_token=$(curl -k -s -X POST -u "$GITEA_USER:$GITEA_PASS" "$GITEA_URL/api/v1/users/$GITEA_USER/tokens" \
  -H "Content-Type: application/json" \
  -d '{"name": "Gitea token", "scopes": ["write:repository", "write:user"]}' | jq -r '.sha1')

echo "Migrating GitHub repo to Gitea..."
curl -k -X POST "$GITEA_URL/api/v1/repos/migrate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $auth_token" \
  -d "{\"clone_addr\": \"$REPO_CLONE_URL\", \"repo_name\": \"$REPO_NAME\"}"

# -------------------------------
# Setup Webhook in Gitea
# -------------------------------

echo "Creating webhook..."
curl -k -X POST "$GITEA_URL/api/v1/repos/$GITEA_USER/$REPO_NAME/hooks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $auth_token" \
  -d '{
    "type": "gitea",
    "active": true,
    "events": ["create"],
    "config": {
      "content_type": "json",
      "url": "http://el-image-build-listener.default:8080",
      "http_method": "POST"
    }
  }'

echo "Setup complete."
