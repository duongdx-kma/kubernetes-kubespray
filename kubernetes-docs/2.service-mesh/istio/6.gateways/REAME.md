# Istio Gateway

## I. Pre-requisite:

### 1. create deployment `deployment/webapp-original` and `deployment/webapp-experimental`:
```yaml
# original config
image: richardchesterwood/istio-fleetman-webapp-angular:6

# original experimental
image: richardchesterwood/istio-fleetman-webapp-angular:6-experimental
```


### 2. create canary with following rule: `90% to original`, `10% to experimental`

**config `DestinationRule`**
```yaml
kind: DestinationRule
apiVersion: networking.istio.io/v1
metadata:
  name: fleetman-webapp
spec:
  host: fleetman-webapp
  subsets:
  - name: original-subset
    labels:
      version: original
  - name: experimental-subset
    labels:
      version: experimental
```

**config `VirtualService`**
```yaml
kind: VirtualService
apiVersion: networking.istio.io/v1
metadata:
  name: fleetman-webapp
spec:
  hosts:
  - fleetman-webapp
  http:
  - route:
    - destination:
        host: fleetman-webapp
        subset: original-subset # <--- directo DestinationRule  
      weight: 90
    - destination:
        host: fleetman-webapp
        subset: experimental-subset # <--- directo DestinationRule  
      weight: 10
```

### 3. Verify configuration:

**3.1 Try connect from a `POD`**

- Trying curl to `fleetman-webapp.default.svc.cluster.local` from inside `k8s-pod`. 

- We can see only some request approached to `experimental version`. almost request be distributed to `original version`

```bash
# Command
while true;
do
    curl -s http://fleetman-webapp.default.svc.cluster.local/ | grep -i title;
    sleep 1;
done;

# The result:
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>

```

**3.2 Try connect from a `Browser` or `Client machine`**

- The config `Splitting Traffic` doesn't work. It still response `50%-50%` mechanism

```bash
# command
while true;
do
    curl -s http://10.0.12.6:30080/ | grep -i title;
    sleep 1;
done;

# Result
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
  <title>Fleet Management Istio Premium Enterprise Edition</title>
  <title>Fleet Management</title>
  <title>Fleet Management</title>
```