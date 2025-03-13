## I. Prerequisite

### 0. Config `ubuntu user` can run `sudo` without password
```bash
USER=ubuntu
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER

# check
sudo -n true; echo $?
```

### 1. clone `kubespray`:
```bash
git clone git@github.com:kubernetes-sigs/kubespray.git --branch release-2.26
```

### 2. copy `sample` to `yourself cluster`
```bash
cp -rf inventory/sample inventory/prod
```

### 3. create ansible inventory `hosts.ini`
```yaml
# hosts.ini
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all]
haproxy ansible_host=192.168.56.08 ip=192.168.56.08
master1 ansible_host=192.168.56.11 ip=192.168.56.11 etcd_member_name=etcd1
master2 ansible_host=192.168.56.12 ip=192.168.56.12 etcd_member_name=etcd2
master3 ansible_host=192.168.56.13 ip=192.168.56.13 etcd_member_name=etcd3

worker1 ansible_host=192.168.56.16 ip=192.168.56.16
worker2 ansible_host=192.168.56.17 ip=192.168.56.17

[kube_control_plane]
master1
master2
master3

[etcd]
master1
master2
master3

[kube_node]
worker1
worker2

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr

[all:vars]
ansible_ssh_private_key_file=client.pem
ansible_user=deploy
```

### 4. config `K8s` - by override `group_vars/k8s_cluster/k8s-cluster.yml`
```yaml
# Kubernetes version
kube_version: v1.30.4

# Kubernetes internal network for services, unused block of space.
kube_service_addresses: 10.233.0.0/18

# internal network. When used, it will assign IP
# addresses from this range to individual pods.
# This network must be unused in your network infrastructure!
kube_pods_subnet: 10.233.64.0/18

# DNS configuration.
# Kubernetes cluster name, also will be used as DNS domain
cluster_name: cluster.local

# Can be coredns, coredns_dual, manual or none
dns_mode: coredns

# Kube-proxy proxyMode configuration.
# Can be ipvs, iptables
kube_proxy_mode: iptables

## Container runtime
## docker for docker, crio for cri-o and containerd for containerd.
## Default: containerd
container_manager: containerd

# audit log for kubernetes
kubernetes_audit: false

# Choose network plugin (cilium, calico, kube-ovn, weave or flannel. Use cni for generic cni plugin)
# Can also be set to 'cloud', which lets the cloud provider setup appropriate routing
kube_network_plugin: calico
```

### 5. config `addons` - by override `group_vars/k8s_cluster/addons.yml`
```yaml
# Helm deployment
helm_enabled: true

# enable metric server for top node, pod...
metrics_server_enabled: true

# enable ingress nginx
ingress_nginx_enabled: true

# enable metallb
metallb_enabled: true
USER=ubuntu

cert_manager_enabled: false
argocd_enabled: false
kube_vip_enabled: false
```

### 5.1 config `addons ingress-nginx`:
```yaml
# Nginx ingress controller deployment
ingress_nginx_enabled: true
ingress_nginx_service_type: LoadBalancer
ingress_publish_status_address: ""
ingress_nginx_nodeselector:
  kubernetes.io/os: "linux"
ingress_nginx_tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Equal"
    value: ""
    effect: "NoSchedule"
ingress_nginx_namespace: "ingress-nginx"
ingress_nginx_insecure_port: 80
ingress_nginx_secure_port: 443
ingress_nginx_configmap:
  map-hash-bucket-size: "128"
  ssl-protocols: "TLSv1.2 TLSv1.3"
ingress_nginx_class: nginx
ingress_nginx_without_class: false
```

### 5.2 config `addons metallb`:
```yaml
# MetalLB deployment
metallb_enabled: true
metallb_speaker_enabled: "{{ metallb_enabled }}"
metallb_namespace: "metallb-system"
metallb_version: v0.13.9
metallb_protocol: "layer2"
metallb_port: "7472"
metallb_memberlist_port: "7946"
metallb_config:
  speaker:
    nodeselector:
      kubernetes.io/os: "linux"
    tolerations:
      - key: "node-role.kubernetes.io/control-plane"
        operator: "Equal"
        value: ""
        effect: "NoSchedule"
  controller:
    nodeselector:
      kubernetes.io/os: "linux"
    tolerations:
      - key: "node-role.kubernetes.io/control-plane"
        operator: "Equal"
        value: ""
        effect: "NoSchedule"
  address_pools:
    primary:
      ip_range:
        - 10.0.12.104 - 10.0.12.111
      auto_assign: true
  layer2:
    - primary
```

### 5.3 config `calico` for `metallb`:
```yaml
calico_advertise_service_loadbalancer_ips:
- 10.0.12.104/29
```

### 6. config `loadbalancer` - by override `group_vars/all/all.yml`
```yaml
## External LB example config
loadbalancer_apiserver:
  address: 10.0.12.12
  port: 16443

## Internal loadbalancers for apiservers
# loadbalancer_apiserver_localhost: true
# valid options are "nginx" or "haproxy"
loadbalancer_apiserver_type: nginx  # valid values "nginx" or "haproxy"

## Local loadbalancer should use this port
## And must be set port 6443
loadbalancer_apiserver_port: 6443
```

## II. Initialize Kubernetes cluster:
### 1. Create cluster:
```bash
# export PROJECT_PATH=/home/duongdx/Projects/k8s-kubespary
export PROJECT_PATH=/home/xuanduong/Projects/kubernetes-kubespray
export KUBESPRAY_VERSION=v2.26.0
export USER=ubuntu
export INVENTORY_PATH=/inventory

# Start kubespray container
docker run --rm -it --mount type=bind,source=$PROJECT_PATH/kubespray-inventory,dst=$INVENTORY_PATH \
  --mount type=bind,source=$PROJECT_PATH/kubespray-inventory/secret.pem,dst=/root/.ssh/id_ed25519 \
  --mount type=bind,source=$PROJECT_PATH/kubespray-inventory/secret.pem,dst=/home/$USER/.ssh/id_ed25519 \
  quay.io/kubespray/kubespray:$KUBESPRAY_VERSION bash

# export variable
export USER=ubuntu
export INVENTORY_PATH=/inventory

# check ansible can't get variable or not?
ansible -i $INVENTORY_PATH/hosts.ini -e @$INVENTORY_PATH/cluster-variable.yml all -m debug -a "var=calico_advertise_service_loadbalancer_ips"

# check status
ansible -m ping all -i $INVENTORY_PATH/hosts.ini

# install haproxy as External Loadbalancer
ansible-playbook -i $INVENTORY_PATH/hosts.ini -e @$INVENTORY_PATH/cluster-variable.yml $INVENTORY_PATH/haproxy.yml --become --become-user=root

# init kubernetes cluster
ansible-playbook -i $INVENTORY_PATH/hosts.ini \
  -e @$INVENTORY_PATH/cluster-variable.yml \
  --user=$USER --become --become-user=root \
  cluster.yml
```

### 2. Download `kube-config file`
```bash
# create kube-config
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
# copy kube config
export MASTER1_IP=10.0.12.6

scp -i kubespray-inventory/secret.pem $USER@$MASTER1_IP:/home/$USER/.kube/config ~/.kube/kubespray-cluster-config

export KUBECONFIG=~/.kube/kubespray-cluster-config
```

## III. Verify cluster:

### 1. Testing deploy:
```bash
k apply -f kubernetes-docs/0.manifests/ingress-nginx/default-ingress.yml
k apply -f kubernetes-docs/0.manifests/ingress-nginx/default-ingress.yml
```

### 2. Custom ingress nginx `404-default`
```bash
k apply -f kubernetes-docs/0.manifests/ingress-nginx/nginx-404.yml

k patch daemonset ingress-nginx-controller -n ingress-nginx \
  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value":"--default-backend-service=ingress-nginx/custom-404"}]'

k rollout restart daemonset ingress-nginx-controller -n ingress-nginx
```

### 3. Testing Service type `NodePort`, `Loadbalancer`:

### 4. Testing Connect:
```
- Node to Pod (Same node)
- Pod to Pod (Same node)
- Node to Pod (Difference node)
- Pod to Pod (Difference node)
```

### 5. Testing `helm`:
```bash
```