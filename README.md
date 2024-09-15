# argocd-manifests
GitOps deployment for an app of apps model

## Prerequisites

### Install tooling
  1. `brew install helm kubectl kubectx kubeseal`

### Gather authentication information
  1. `cat /etc/rancher/k3s/k3s.yaml` on truenas, copy the contents to `~/.kube/config` on the local machine.

### Allow kubectl traffic
  1. On truenas run `sudo iptables -I INPUT 4 -p tcp -s 10.48.64.0/24 --dport 6443 -j ACCEPT`

  - Replace `10.48.64.0/24` with the cidr range of your local machine
  - Note: This will not persist across reboots

Test the connection with `kubectl get nodes`

### Install ArgoCD
  1. run `bootstrap_cluster.sh` locally