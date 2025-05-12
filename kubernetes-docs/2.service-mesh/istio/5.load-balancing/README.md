# Isito Load Balancing

We can using `Destination Rule` for load balancing purpose. Following the document: https://istio.io/latest/docs/reference/config/networking/destination-rule/#LoadBalancerSettings

## I. Example:

### 1. Example `Round_Robin`:
```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: bookinfo-ratings
spec:
  host: ratings.prod.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
```

### 2. Example `Load Balancer Sticky Sessions`:
```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: bookinfo-ratings
spec:
  host: ratings.prod.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpCookie:
          name: user
          ttl: 0s
```

## II. Stickyness Demo:

### 1. create a `VirtualService` and `Destination` with only 1 `destination` for testing `Roud_robin`:


**1.1: lb.destination_rule.yml**

```yaml
kind: DestinationRule
apiVersion: networking.istio.io/v1
metadata:
  namespace: default
  name: fleetman-staff-service
spec:
  host: fleetman-staff-service
  subsets:
  - name: all-staff-service-pod # check <---
    labels:
      app: staff-service
```

**1.2: lb.virtual_service.yml**

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
        subset:  all-staff-service-pod # check <---
      # weight: 100 # not need if there's only one 
```

### 2. apply the artifacts and check the result:

**2.1 testing get pod**

```bash
while true;
do 
    curl http://10.0.12.6:30080/api/vehicles/driver/City%20Truck;
    echo 
    sleep 1;
done
```

**2.2 result: we can see, the request has been distributed across all version (v1 and v2)**
```bash
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
```

### 3. Apply Load Balancing with `httpHeaderName`:

**3.1: lb.httpHeaderName.DestinationRule.yml**

```yaml
kind: DestinationRule
apiVersion: networking.istio.io/v1
metadata:
  namespace: default
  name: fleetman-staff-service
spec:
  host: fleetman-staff-service
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpHeaderName: "x-myheader"
  subsets:
  - name: all-staff-service-pod # check <---
    labels:
      app: staff-service
```

**3.2: Check result when we pass `--header "x-myheader: 192"`**
The request was stickied with specific server
```bash
while true;
do
    curl --header "x-myheader: 192" http://10.0.12.6:30080/api/vehicles/driver/City%20Truck;
    echo
    sleep 1;
done
# result:
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/1.jpg"}
```

**3.2: Check result when we pass `--header "x-myheader: 199"`**
Try again, The request was stickied with specific server
```bash
while true;
do
    curl --header "x-myheader: 199" http://10.0.12.6:30080/api/vehicles/driver/City%20Truck;
    echo
    sleep 1;
done
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
{"name":"Pam Parry","photo":"https://rac-istio-course-images.s3.amazonaws.com/placeholder.png"}
```