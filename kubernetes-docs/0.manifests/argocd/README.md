## I. create chart by yourself:
### 1. create new repo:
```bash
helm create soc-chart
```

### 2. verify helm template
```bash
helm template [chart_name] [chart_folder]

helm template soc-api soc-chart/
```

### 3. Add chart from chart folder for testing

3.1: package chart
```bash
helm package [chart_path] -d [destination_dir] --version [chart_version] --app-version [app_version]
helm package ./
helm package . --version 0.1.1 --app-version 1.0.1
```

3.2: `indexing` the chart repo
```bash
helm repo index .
```

3.3: add helm repo and testing:
```bash
git add .
git commit -m ""
git push origin HEAD
```

### 4. Public helm chart to `registry`
```bash
helm registry login -u [user_name] [registry_url

helm push [CHART_PACKAGE] oci://registry-hn01.fke.fptcloud.com/87bc0a7b-afa4-4520-bf39-4d0868593f47]
```

### 5. Pull chart from `OCI Registry`
```bash
helm pull oci://[registry_url]/[project]/[chart_name] --version [version]
helm pull oci://registry-hn01.fke.fptcloud.com/87bc0a7b-afa4-4520-bf39-4d0868593f47/command-center --version 0.1.0
```

### 6. Show chart values with OCI:
```bash
helm show all oci://[registry_url]/[project]/[chart_name] --version [version]
helm show all oci://registry-hn01.fke.fptcloud.com/87bc0a7b-afa4-4520-bf39-4d0868593f47/command-center
```

### 7. helm install with `OCI`:
```bash
helm install myrelease oci://localhost:5000/helm-charts/mychart --version 0.1.0
```

### 8. helm upgrade with `OCI`:
```bash
helm upgrade myrelease oci://localhost:5000/helm-charts/mychart --version 0.2.0
```

## II. hand-ons `argocd`

### 1. install and config `argocd`

#### 1.1 add repo argo:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
```

#### 1.2 search chart inside repo:
```bash
helm search repo argo

NAME                      	CHART VERSION	APP VERSION  	DESCRIPTION
argo/argo                 	1.0.0        	v2.12.5      	A Helm chart for Argo Workflows
argo/argo-cd              	7.8.3        	v2.14.2      	A Helm chart for Argo CD, a declarative, GitOps...
argo/argo-ci              	1.0.0        	v1.0.0-alpha2	A Helm chart for Argo-CI
argo/argo-events          	2.4.13       	v1.9.5       	A Helm chart for Argo Events, the event-driven ...
argo/argo-lite            	0.1.0        	             	Lighweight workflow engine for Kubernetes
argo/argo-rollouts        	2.39.0       	v1.8.0       	A Helm chart for Argo Rollouts
argo/argo-workflows       	0.45.7       	v3.6.4       	A Helm chart for Argo Workflows
argo/argocd-applicationset	1.12.1       	v0.4.1       	A Helm chart for installing ArgoCD ApplicationSet
argo/argocd-apps          	2.0.2        	             	A Helm chart for managing additional Argo CD Ap...
argo/argocd-image-updater 	0.12.0       	v0.15.2      	A Helm chart for Argo CD Image Updater, a tool ...
argo/argocd-notifications 	1.8.1        	v1.2.1       	A Helm chart for ArgoCD notifications, an add-o...
```

#### 1.3 get chart values (without install)

```bash
# command
helm show values argo/argo-cd
```

#### 1.4. install argocd
```yaml
# argo-cd value
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --values helm/argocd.values.yml
```

#### 1.5. create argocd-tls selfsign for testing purpose:
```bash

# generate self sign cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout argocd-tls.key \
  -out argocd-tls.crt \
  -subj "/CN=argocd.mycompany.com/O=ArgoCD"
```

#### 1.6. expose argocd with port-forwarding
```bash
k port-forward svc/argocd-server -n argocd 8443:443

https://localhost:8443
```

### 2. Practice with argocd-cli:

#### 2.1 install `argocd-cli`
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

#### 2.2 login with `argocd-cli`
```bash
argocd login [argocd_endpoint] --username [username] --insecure
argocd login localhost:8443 --insecure --username admin
```

#### 2.3 practices:
```bash
### list argocd app
argocd app list 

NAME                   CLUSTER                         NAMESPACE  PROJECT         STATUS     HEALTH   SYNCPOLICY  CONDITIONS  REPO                                                                 PATH  TARGET
argocd/command-center  https://kubernetes.default.svc  soc        command-center  OutOfSync  Healthy  Manual <none> registry-hn01.fke.fptcloud.com/repo_name        *

### check app diff
argocd app diff argocd/command-center


### result:
===== /Secret soc/database-credential ======
0a1,11
> apiVersion: v1
> data:
>   DB_NAME: ++++++++
>   DB_PASSWORD: ++++++++
>   DB_USER: ++++++++
> kind: Secret
> metadata:
>   labels:
>     argocd.argoproj.io/instance: command-center
>   name: database-credential
>   namespace: soc

===== /Service soc/command-center ======
16c16
<     helm.sh/chart: command-center-0.1.4
---
>     helm.sh/chart: command-center-0.1.5

===== /ServiceAccount soc/command-center ======
14c14
<     helm.sh/chart: command-center-0.1.4
---
>     helm.sh/chart: command-center-0.1.5

===== apps/Deployment soc/command-center ======
15c15
<     helm.sh/chart: command-center-0.1.4
---
>     helm.sh/chart: command-center-0.1.5
152c152
<         helm.sh/chart: command-center-0.1.4
---
>         helm.sh/chart: command-center-0.1.5
155c155,158
<       - image: registry-hn01.fke.fptcloud.com/87bc0a7b-afa4-4520-bf39-4d0868593f47/sit-soc-api:1739519315802
---
>       - envFrom:
>         - secretRef:
>             name: database-credential
>         image: registry-hn01.fke.fptcloud.com/87bc0a7b-afa4-4520-bf39-4d0868593f47/sit-soc-api:1739519315802

===== autoscaling/HorizontalPodAutoscaler soc/command-center ======
13c13
<     helm.sh/chart: command-center-0.1.4
---
>     helm.sh/chart: command-center-0.1.5

===== networking.k8s.io/Ingress soc/command-center ======
15c15
<     helm.sh/chart: command-center-0.1.4
---
>     helm.sh/chart: command-center-0.1.5
```

#### 2.3 dry-run sync `OutOfSync` app:
```bash
# dry-run app sync
argocd app sync <app-name> --dry-run

Name:               argocd/command-center
Project:            command-center
Server:             https://kubernetes.default.svc
Namespace:          soc
URL:                https://argocd.duongdx.com/applications/argocd/command-center
Source:
- Repo:             registry-hn01.fke.fptcloud.com/87bc0a7b-afa4-4520-bf39-4d0868593f47
  Target:           *
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        OutOfSync from *
Health Status:      Healthy

Operation:          Sync
Sync Revision:      0.1.5
Phase:              Succeeded
Start:              2025-03-03 01:31:50 +0700 +07
Finished:           2025-03-03 01:31:50 +0700 +07
Duration:           0s
Message:            successfully synced (no more tasks)

GROUP              KIND                     NAMESPACE  NAME                 STATUS     HEALTH   HOOK  MESSAGE
                   ServiceAccount           soc        command-center       OutOfSync                 serviceaccount/command-center configured (dry run)
                   Secret                   soc        database-credential  OutOfSync  Missing        secret/database-credential created (dry run)
                   Service                  soc        command-center       OutOfSync  Healthy        service/command-center configured (dry run)
apps               Deployment               soc        command-center       OutOfSync  Healthy        deployment.apps/command-center configured (dry run)
autoscaling        HorizontalPodAutoscaler  soc        command-center       OutOfSync  Healthy        horizontalpodautoscaler.autoscaling/command-center configured (dry run)
networking.k8s.io  Ingress                  soc        command-center       OutOfSync  Healthy        ingress.networking.k8s.io/command-center configured (dry run)
```

#### 2.4 sync `OutOfSync` app:
```bash
argocd app sync [application_name] --prune
argocd app sync argocd/command-center --prune
```