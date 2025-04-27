
## I. install istio with helm

### 1. Add helm repo:
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

### 2. Install the `Istio base` chart which contains cluster-wide Custom Resource Definitions (CRDs) which must be installed prior to the deployment of the Istio control plane:
```bash
helm install istio-base istio/base -n istio-system --create-namespace --values istio-base.values.yml
```

### 3. Install the `Istio Control Plan` with `istiod` service:
```bash
helm install istiod istio/istiod -n istio-system --values istiod.values.yml
```

### 4. Install the `Istio Ingress` which will take care route traffic from cluster to our Pods:
```bash
helm install istio-ingress istio/gateway -n istio-system --values istio-ingress.values.yml
```

### 5. check result: 
```bash
helm list -n istio-system 

NAME         	NAMESPACE   	REVISION	UPDATED                                	STATUS  	CHART         	APP VERSION
istio-base   	istio-system	1       	2025-04-02 12:51:11.820272649 +0700 +07	deployed	base-1.25.1   	1.25.1     
istio-ingress	istio-system	1       	2025-04-02 12:59:57.102163731 +0700 +07	deployed	gateway-1.25.1	1.25.1     
istiod       	istio-system	1       	2025-04-02 12:56:54.433395827 +0700 +07	deployed	istiod-1.25.1 	1.25.1   
```

### 6. Deploy an App onto the Mesh:

Istio can automatically inject the proxy container into any new Pods. You configure that by apply a label to the `namespace(s)` you want to use with Istio

```bash
# command
k label namespace [namespace_name] istio-injection=enabled
k label namespace default istio-injection=enabled

# check namespace
k describe namespace default
```


## II. Install kiali:

### 1. Install pre-requisite `grafana` and `prometheus`:
```bash
# Add Prometheus and Grafana repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  -f prometheus.values.yml

helm install grafana grafana/grafana \
  --namespace monitoring \
  -f grafana.values.yml
```

### 2. Install kiali:
```bash
helm repo add kiali https://kiali.org/helm-charts

helm repo update kiali

helm show values kiali/kiali-server > kiali-server.values.yml

helm install  kiali-server kiali/kiali-server --namespace istio-system --values=kiali-server.values.yml

# get Kiali token

kubectl create token [kiali-service-account] -n istio-system

kubectl create token kiali -n istio-system
```