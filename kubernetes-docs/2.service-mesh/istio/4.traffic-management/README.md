# 4. Traffic Management

## I. Canary Deployment:

### 1. create deployment `deployment/staff-service` and `deployment/staff-service-green`:
```yaml
# staff with photo
image: richardchesterwood/istio-fleetman-staff-service:6
# staff without photo
image: richardchesterwood/istio-fleetman-staff-service:6-placeholder
```

### 2. scale deployment:
```bash
k scale --replicas=1 deployment/staff-service
deployment.apps/staff-service scaled

k scale --replicas=1 deployment/staff-service-green
deployment.apps/staff-service-green scaled
```

### 3. create canary with following rule: `90% to v1`, `10% to v2`
```yaml
kind: DestinationRule
apiVersion: networking.istio.io/v1
metadata:
  namespace: default
  name: fleetman-staff-service
spec:
  host: fleetman-staff-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

```yaml
kind: VirtualService
apiVersion: networking.istio.io/v1
metadata:
  namespace: default
  name: fleetman-staff-service
spec:
  hosts:
  - fleetman-staff-service
  http:
  - route:
    - destination:
        host: fleetman-staff-service
        subset: v1
      weight: 0
    - destination:
        host: fleetman-staff-service
        subset: v2
      weight: 100
```

### 4. apply the `virtual_service` and `destination_rule` config:

apply the manifests:
```bash
k apply -f canary.virtual_service.yml 
virtualservice.networking.istio.io/fleetman-staff-service created

k apply -f canary.destination_rule.yml 
destinationrule.networking.istio.io/fleetman-staff-service created
```

check result:
```bash
k get vs                              
NAME                     GATEWAYS   HOSTS                                                  AGE
fleetman-staff-service              ["fleetman-staff-service.default.svc.cluster.local"]   73s

k get dr                                       
NAME                     HOST                                               AGE
fleetman-staff-service   fleetman-staff-service.default.svc.cluster.local   65s
```

## II. Istio `VirtualService`:

### 1. some command:
```bash
# method 1:
k get virtualservices

# method 2:
k get vs
```

### 2. analyze the `VirtualService` config 
```yaml
kind: VirtualService
apiVersion: networking.istio.io/v1
metadata:
  namespace: default
  name: fleetman-staff-service # "just" a name  for this virtualservice
spec:
  hosts:
  - fleetman-staff-service # The Service DNS (there regular K8S service) name that we're applying routing rules to. If call the service in other namespace we have to define fully qualified domain name (FQDN) fleetman-staff-service.dfault.svc.cluster.local
  http:
  - route:
    - destination:
        host: fleetman-staff-service # The target DNS name
        subset: v1  # Destination rule
      weight: 0
    - destination:
        host: fleetman-staff-service # The target DNS name
        subset: v2 # Destination rule
      weight: 100
```

## III. Istio `DestinationRules`:

### 1. some command:
```bash
# method 1:
k get destinationrules

# method 2:
k get dr
```

### 2. analyze the `DestinationRules` config 
```yaml
kind: DestinationRule # Defining which pods should be part of each subets
apiVersion: networking.istio.io/v1
metadata:
  namespace: default
  name: fleetman-staff-service
spec:
  host: fleetman-staff-service # The Service DNS (there regular K8S service) name that we're applying routing rules to. If call the service in other namespace we have to define fully qualified domain name (FQDN) fleetman-staff-service.dfault.svc.cluster.local
  subsets:
  - name: v1 # Name of the subset. we can set other (i have to match the VirtualService.subset)
    labels: # Selector
      version: v1 # Find pods with label "v1"
  - name: v2
    labels:
      version: v2
```