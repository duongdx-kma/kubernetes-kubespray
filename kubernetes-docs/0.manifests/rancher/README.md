# Install Rancher:

### 1. Add Rancher chart:
```bash
helm repo add rancher https://releases.rancher.com/server-charts/stable
```

### 2. Check chart:
```bash
helm search repo rancher
NAME             	CHART VERSION	APP VERSION	DESCRIPTION                                       
rancher/rancher  	2.10.3       	v2.10.3    	Install Rancher Server to manage Kubernetes clu...
longhorn/longhorn	1.0.0        	v1.0.0     	Longhorn is a distributed block storage system
```

### 3. get `rancher default value`:
```bash
helm show values rancher/rancher > rancher/rancher-df.values.yml
```