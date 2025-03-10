## I. Prerequisite

### 1. clone `kubespray`:
```bash
git clone git@github.com:kubernetes-sigs/kubespray.git --branch release-2.26
```

### 2. copy `sample` to `yourself cluster`
```bash
cp -rf inventory/sample inventory/prod
```

### 3. create ansible inventory `hosts.yml`
```yaml
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all]
master1 ansible_host=192.168.10.11 ip=192.168.10.11 etcd_member_name=etcd1
master2 ansible_host=192.168.10.12 ip=192.168.10.12 etcd_member_name=etcd2
master3 ansible_host=192.168.10.13 ip=192.168.10.13 etcd_member_name=etcd3

worker1 ansible_host=192.168.10.14 ip=192.168.10.14
worker2 ansible_host=192.168.10.15 ip=192.168.10.15

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
# enable metric server for top node, pod...
metrics_server_enabled: true

# enable ingress nginx
ingress_nginx_enabled: true

cert_manager_enabled: false
argocd_enabled: false
kube_vip_enabled: false
```

### 6. config `loadbalancer` - by override `group_vars/all/all.yml`
```yaml
## External LB example config
apiserver_loadbalancer_domain_name: "elb.some.domain"
  loadbalancer_apiserver:
    address: 1.2.3.4
    port: 1234

## Internal loadbalancers for apiservers
# loadbalancer_apiserver_localhost: true
# valid options are "nginx" or "haproxy"
loadbalancer_apiserver_type: nginx  # valid values "nginx" or "haproxy"

## Local loadbalancer should use this port
## And must be set port 6443
loadbalancer_apiserver_port: 6443
```

### 7. Create cluster:
```bash
#Start kubespray container
export $PROJECT_PATH=/home/duongdx/Projects/k8s-kubespary

docker run --rm -it --mount type=bind,source=$PROJECT_PATH/kubespray-inventory,dst=/inventory \
  --mount type=bind,source=$PROJECT_PATH/client.pem,dst=/root/.ssh/client.pem \
  --mount type=bind,source=$PROJECT_PATH/client.pem,dst=/home/deploy/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.26.0 bash

ansible-playbook -i /inventory/inventory.ini cluster.yml --user=deploy --become
```# kubernetes-kubespray
