# Istio Hand-ons

## I. Install Istio:
### 1. install `istioctl` on linux
```bash
# install 
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.4 sh -

# moving istio to /opt/
sudo mv istio-1.24.4/ /opt/

# export $PATH
export PATH="$PATH:/opt/istio-1.24.4/bin"

# check istictl version
istioctl version --remote=false
```

### 2. install `istio`

**check K8s cluster before install istio**
```bash
# command
istioctl x precheck

# result
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
  To get started, check out https://istio.io/latest/docs/setup/getting-started/.
```