#!/bin/bash

##############################################################################################################
# Pre-requisites:
# - kubectl, and helm are installed on the local machine.
# - `cat /etc/rancher/k3s/k3s.yaml` on truenas, copy the contents to ~/.kube/config on the local machine.
# - on truenas run `sudo iptables -I INPUT 4 -p tcp -s 10.48.64.0/24 --dport 6443 -j ACCEPT` to allow traffic
#     - test kubectl get nodes
##############################################################################################################

##############################################################################################################
# This script is used to bootstrap a Kubernetes cluster with ArgoCD and Sealed Secrets using Helm charts.
# - install ArgoCD and Sealed Secrets in the argocd namespace.
# - add the ArgoCD helm repo if it is missing and install ArgoCD using helm.
# - check if helm is installed and install it if it is missing.
# - check if the ArgoCD helm repo is added and add it if it is missing.
# This script is run on the local machine, from the root of the repo.
##############################################################################################################

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

# Install ArgoCD using helm
helm dependency update argocd
helm upgrade --install argocd argocd -n argocd --create-namespace --wait --timeout 120s --values globalValues.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Wait for the service to be deployed
echo "Waiting for the service to be deployed..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Gather the argocd admin user password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo)

# Print the generated password to the console
echo "ArgoCD admin password: $ARGOCD_PASSWORD"
