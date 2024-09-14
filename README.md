# argocd-manifests
GitOps deployment for an app of apps model

## Prerequisites
### Create a GitHub Personal Access Token (PAT)

	1.	Go to GitHub Settings.
	2.	Click Generate new token (classic) or follow the updated instructions if needed.
	3.	Name the token (e.g., “ArgoCD Access Token”).
	4.	Under Select scopes, choose:
	•	repo (for full control of private repositories)
	5.	Generate the token and copy it (save it securely, as you won’t be able to view it again).

### Install tooling
  1. `brew install argocd kubectl kubectx helm`

### Gather authentication information
  1. `cat /etc/rancher/k3s/k3s.yaml` on truenas, copy the contents to `~/.kube/config` on the local machine.

### Allow kubectl traffic
  1. On truenas run `sudo iptables -I INPUT 4 -p tcp -s 10.48.64.0/24 --dport 6443 -j ACCEPT`

Test the connection with `kubectl get nodes`

### Create argocd namespace
  1. `kubectl create namespace argocd`

### Create kube secret for argocd
  1. Create a secret for the argocd server
```shell
kubectl create secret generic git-creds \
  --namespace argocd \
  --from-literal=username=<user_name> \
  --from-literal=password=<github_toekn>
```
  2. kubectl apply -f git-creds.yaml

### Install ArgoCD
  1. run `bootstrap_cluster.sh` locally