# Elastic-Cloud-Kubernetes (ECK)

##  I. Installation:

### 1. add helm repo and get value:
```bash
helm repo add elastic https://helm.elastic.co

helm show values elastic/eck-operator > eck-operator.df.values.yml
```