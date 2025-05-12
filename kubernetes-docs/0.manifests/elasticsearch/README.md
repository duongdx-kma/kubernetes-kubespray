# Deploy Elastic Stack with helm

## I. Install `Cert-manager` and generate `elastic-cert`
### 1. install `cert-manager`
```bash
helm repo add jetstack https://charts.jetstack.io --force-update

helm show values jetstack/cert-manager > cert-manager.df.values.yml

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

### 2. generate rootCA.cert
```bash
openssl genrsa -des3 -passout pass:Abcd123 -out rootCA.key 2048

country="VN"
state="HN"
locality="HN"
organization="MyCompany"
organizationalunit="MyCompany"
commonname="duongdx-ca.com"
email="duongdx@gmail.com"

openssl req -x509 -new -nodes -key rootCA.key -passin pass:Abcd123 \
-sha256 -days 1825 -out rootCA.crt \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
```

### 3. Create root-ca k8s-secret:
```bash
openssl rsa -in rootCA.key -out rootCA-decrypted.key

kubectl create secret tls root-ca \
  --cert=rootCA.crt \
  --key=rootCA.key \
  -n cert-manager
```

### 4. Create `Cert-manager Issuer: issuer.yml`
```bash
cat <<EOF > cert-manager/issuer.yml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: root-ca
EOF
```

### 4. Create `Cert-manager Certificate: elasticsearch-http-cert.yml`
```bash
cat <<EOF > cert-manager/elasticsearch-http-cert.yml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: elasticsearch-http-cert
  namespace: elastic
spec:
  secretName: elasticsearch-http-cert
  commonName: elasticsearch.elastic.svc
  dnsNames:
    - elasticsearch-master
    - elasticsearch-master.elastic
    - elasticsearch-master.elastic.svc
    - elasticsearch.duongdx.com
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  duration: 8760h
  privateKey:
    algorithm: RSA
    size: 2048
EOF
```

### 5. Create `Cert-manager Certificate: elasticsearch-transport-cert.yml`
```bash
cat <<EOF > cert-manager/elasticsearch-transport-cert.yml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: elasticsearch-transport-cert
  namespace: elastic
spec:
  secretName: elasticsearch-transport-cert
  commonName: elasticsearch.elastic.svc
  dnsNames:
    - elasticsearch-master
    - elasticsearch-master.elastic
    - elasticsearch-master.elastic.svc
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  duration: 8760h
  privateKey:
    algorithm: RSA
    size: 2048

EOF
```

### 5. apply resource:
```bash
k apply -f cert-manager/issuer.yml
k apply -f cert-manager/elasticsearch-http-cert.yml
k apply -f cert-manager/elasticsearch-transport-cert.yml

k describe certificate elasticsearch-transport-cert -n elastic
k describe certificate elasticsearch-http-cert -n elastic
```

### 6. check the certificate:
```bash
# command for get certificate:
k get secret elasticsearch-http-cert -n elastic -o jsonpath="{.data['tls\.crt']}" | base64 -d > elasticsearch-http.crt
 
# command for example certificate:
openssl x509 -in elasticsearch-http.crt -text -noout

# result:
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            0c:32:6a:e7:5d:59:a7:d8:18:dc:59:1e:59:e8:9b:7d
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = VN, ST = HN, L = HN, O = MyCompany, OU = MyCompany, CN = duongdx-ca.com, emailAddress = duongdx@gmail.com
        Validity
            Not Before: Mar 23 14:25:24 2025 GMT
            Not After : Mar 23 14:25:24 2026 GMT
        Subject: CN = elasticsearch.elastic.svc
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    ...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                BA:B7:8D:AC:4C:EF:48:A0:BC:D5:CB:C4:1C:F2:8B:A2:AD:0C:0A:09
            X509v3 Subject Alternative Name: 
                DNS:elasticsearch.elastic.svc, DNS:elasticsearch.elastic.svc.cluster.local, DNS:elasticsearch.duongdx.com
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        ...
```

### 7. Update elasticsearch helm value:

After create the certificate we got 2 secret `elasticsearch-transport-cert` and `elasticsearch-http-cert`
**mounting secret to elasticsearch**
```yaml
secretMounts:
  - name: elasticsearch-transport-cert
    secretName: elasticsearch-transport-cert
    path: /usr/share/elasticsearch/config/certs/transport
    defaultMode: 0755
  - name: elasticsearch-http-cert
    secretName: elasticsearch-http-cert
    path: /usr/share/elasticsearch/config/certs/http
    defaultMode: 0755
```

**update /etc/elasticsearch/elasticsearch.yml**
```yaml
esConfig:
  elasticsearch.yml: |
    xpack.security.enabled: true
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.key: certs/transport/tls.key
    xpack.security.transport.ssl.certificate: certs/transport/tls.crt
    xpack.security.transport.ssl.certificate_authorities: certs/transport/ca.crt

    xpack.security.http.ssl.enabled: true
    xpack.security.http.ssl.key: certs/http/tls.key
    xpack.security.http.ssl.certificate: certs/http/tls.crt
    xpack.security.http.ssl.certificate_authorities: certs/http/ca.crt
    xpack.security.http.ssl.client_authentication: optional
```

## II. deploy Elasticsearch stack:

### 1. add helm repo and get value:
```bash
helm repo add elastic https://helm.elastic.co

helm show values elastic/elasticsearch > elasticsearch.df.values.yml

cp elasticsearch.df.values.yml elasticsearch.values.yml
```

### 2. create priority class:
Create priority classes (Optional)
To reduce the chance of ES pods being rescheduled more frequently, we can assign them a priority class so the kube-scheduler gives them a high priority over the other pods.
If a node’s resource capacity is low for new a DaemonSet, the kube-scheduler may evict pods to make space for the new DaemonSet.
So we need priority classes to keep our ES pods from being rescheduled every time this happens. It may be optional in your case depending on your workload and the node sizes.
Check out the following example priority classes and apply them if needed.
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: elastic-cluster-high-priority
value: 1000000
globalDefault: false
description: "High priority for Elasticsearch cluster pods."
```

### 3. Create configmap (script) for `PostStart elasticsearch`

**3.1 Create configmap (script) for `PostStart elasticsearch`**
```bash
# command
k create configmap es-poststart-script \
  --from-file=elasticsearch-poststart.sh=./elasticsearch-poststart.sh \
  -n elastic
```

**3.2 Mounting to `elasticsearch` container: `elasticsearch.values.yml`**
```yaml
extraVolumes:
  - name: poststart-script
    configMap:
      name: es-poststart-script

extraVolumeMounts:
  - name: poststart-script
    mountPath: /usr/share/elasticsearch/config/elasticsearch-poststart.sh
    subPath: elasticsearch-poststart.sh
    readOnly: true
```

**3.3 Config lifecycle `PostStart`**
```bash
lifecycle:
  postStart:
    exec:
      command:
        - bash
        - -c
        - "bash /usr/share/elasticsearch/config/elasticsearch-poststart.sh"
 ```


### 4. install elasticsearch:
```bash
helm install elasticsearch elastic/elasticsearch \
  --namespace elastic --create-namespace \
  --values elasticsearch.values.yml
```

## III. install Kibana:

### 1. create certificate for kibana:
```bash
cat <<EOF > cert-manager/kibana-cert.yml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kibana-cert
  namespace: elastic
spec:
  secretName: kibana-cert
  commonName: kibana.elastic.svc
  dnsNames:
    - kibana
    - kibana.elastic
    - kibana.elastic.svc
    - kibana.duongdx.com
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  duration: 8760h
  renewBefore: 720h
  privateKey:
    algorithm: RSA
    size: 2048
EOF
```

### 2. Generate `kibana-encryption-keys`
```bash
# command for generate key
openssl rand -base64 32
```
**add data to `kibana.yml`**
```yaml
xpack.security.enabled: true
xpack.encryptedSavedObjects.encryptionKey: "S3jWMO2gaKeQVZ/DIsMfGo7GSPAWdU8CZRLDzw8tqnY="
xpack.reporting.encryptionKey: "S9sEmP9H7RgtFvXPBGa+qhDmXNvmB6FhEbXX01t1AgA="
xpack.security.encryptionKey: "hUtAsIstK6SjZn/EIa428eaYKv5fbHL8ZEYqAHM89rY="
```

### 3. Install kibana:
```bash
helm install kibana elastic/kibana \
  --namespace elastic --create-namespace \
  --values kibana.values.yml
```