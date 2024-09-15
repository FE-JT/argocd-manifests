#!/bin/bash

##############################################################################################################
# Pre-requisites:
# - kubectl, kubectx, and helm are installed on the local machine.
# - `cat /etc/rancher/k3s/k3s.yaml` on truenas, copy the contents to ~/.kube/config on the local machine.
# - on truenas run `sudo iptables -I INPUT 4 -p tcp -s 10.48.64.0/24 --dport 6443 -j ACCEPT` to allow traffic
#     - test kubectl get nodes
##############################################################################################################

##############################################################################################################
# This script is used to bootstrap a Kubernetes cluster with ArgoCD and Sealed Secrets using Helm charts.
# - install ArgoCD and Sealed Secrets in the argocd namespace.
# - generate a random password for the ArgoCD admin user and set it in the secret.
# - add the ArgoCD helm repo if it is missing and install ArgoCD using helm.
# - check if helm is installed and install it if it is missing.
# - check if the ArgoCD helm repo is added and add it if it is missing.
# - port-forward the ArgoCD server to localhost:8080 and use kubeseal for secrets.
# This script is run on the local machine.
##############################################################################################################

CLUSTER_IP="10.48.64.12"
GITHUB_USER=$GITHUB_USER
GITHUB_TOKEN=$GITHUB_TOKEN

# Check if helm is installed and install if missing
if ! command -v helm &> /dev/null
then
    echo "Helm not found. Installing helm..."
    brew install helm
fi

# Check if argocd helm repo is added and add if missing
if ! helm repo list | grep argo &> /dev/null
then
    echo "ArgoCD helm repo not found. Adding ArgoCD helm repo..."
    helm repo add argo https://argoproj.github.io/argo-helm
fi

kubectl create namespace argocd

kubectl create secret generic git-creds \
  --namespace argocd \
  --from-literal=username=$GITHUB_USER \
  --from-literal=password=$GITHUB_TOKEN

# Install ArgoCD using helm
helm dependency update argocd
helm upgrade --install argocd argocd -n argocd --create-namespace --wait --timeout 120s --values globalValues.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Expose ArgoCD server
echo "Exposing ArgoCD server..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Wait for the service to be exposed
echo "Waiting for the service to be exposed..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ARGOCD_HTTPS_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
echo "ArgoCD server exposed at https://$CLUSTER_IP:$ARGOCD_HTTPS_PORT"

# Gather the argocd admin user password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo)

# Log into argocd
argocd login $CLUSTER_IP:$ARGOCD_HTTPS_PORT --username admin --password $ARGOCD_PASSWORD --insecure

# Gather the GitHub username and access token
GIT_USERNAME=$(kubectl get secret git-creds -n argocd -o jsonpath="{.data.username}" | base64 -d; echo)
GIT_TOKEN=$(kubectl get secret git-creds -n argocd -o jsonpath="{.data.password}" | base64 -d; echo)

# Configure ArgoCD to use the GitHub repo
argocd repo add https://github.com/FE-JT/argocd-manifests.git \
  --username $GIT_USERNAME \
  --password $GIT_TOKEN

# Deploy the app of apps
kubectl apply -f argocd/templates/appsConfigurator-application.yaml

# Deploy the in cluster secrets
kubectl apply -f argocd/templates/in-cluster-secret.yaml

# Print the generated password to the console
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

helm template appsconfigurator ./ --values ./values.yaml --values ../globalValues.yaml > rendered-appsconfigurator.yaml
