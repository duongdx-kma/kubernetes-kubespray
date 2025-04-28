# 4. Traffic Management

## I. Canary Deployment:

### 1. create deployment:
```yaml
# staff with photo
image: richardchesterwood/istio-fleetman-staff-service:6
# staff without photo
image: richardchesterwood/istio-fleetman-staff-service:6-placeholder
```