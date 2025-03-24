# Longhorn configuration

## I. Install `Longhorn`
### 1. install prerequisite
```bash
sudo apt-get update

apt-get install open-iscsi
apt-get install nfs-common

sudo systemctl enable iscsid
sudo systemctl start iscsid

sudo systemctl enable rpcbind
sudo systemctl start rpcbind
```

### 2. verify prerequisite for longhorn (only MASTER NODE)
```bash
apt-get install jq

curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.3.2/scripts/environment_check.sh | bash
```

### 3. add longhorn helm repository
```bash
helm repo add longhorn https://charts.longhorn.io

helm repo update
```

### 4. get longhorn values and override some config
```bash
helm show values longhorn/longhorn > longhorn.values.yml
```

### 5. install longhorn:
```bash
helm install longhorn longhorn/longhorn --namespace longhorn --create-namespace --values longhorn.values.yml
```

### 6. create longhorn user:
```bash
USER=<USERNAME_HERE>; PASSWORD=<PASSWORD_HERE>; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth

USER=duongdx; PASSWORD=123456; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth

kubectl -n longhorn-system create secret generic basic-auth --from-file=auth
```

### 8. expose:

##### 8.1 get external-ip
```bash
kubectl get services -n ingress-nginx

kubectl get ingress-nginx-controller EXTERNAL-IP
```

##### 8.2 edit /etc/hosts:
```bash
    ...
    192.168.56.201 (ingress-nginx-controller EXTERNAL-IP)  longhorn.ui.duongdx.com
    ...
```

### 9. create ssl secret:
```bash
kubectl create secret tls tls-secret --cert=./ssl/duongdx.crt --key=./ssl/duongdx.key
```

## II. Uninstall longhorn:
```bash
kubectl -n longhorn-system edit settings.longhorn.io deleting-confirmation-flag

set value: true 

helm uninstall longhorn
```

## III. Add `Longhorn` disk to node
### 1. check longhorn nodes:
```bash
# command:
k get lhn  | k get nodes.longhorn.io

# result
NAME      READY   ALLOWSCHEDULING   SCHEDULABLE   AGE
worker1   True    true              True          98m
worker2   True    true              True          162m
```

### 2. create new partition:

**2.1: check filesystem with `lsblk`**
```bash
# command: check block
deploy@worker1:~$ lsblk -f

# result
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0                       7:0    0 63.7M  1 loop /snap/core20/2496
loop1                       7:1    0 63.9M  1 loop /snap/core20/2105
loop2                       7:2    0   87M  1 loop /snap/lxd/27037
loop3                       7:3    0 89.4M  1 loop /snap/lxd/31333
loop4                       7:4    0 40.4M  1 loop /snap/snapd/20671
sda                         8:0    0   64G  0 disk 
├─sda1                      8:1    0    1M  0 part 
├─sda2                      8:2    0    2G  0 part /boot
└─sda3                      8:3    0   62G  0 part 
  └─ubuntu--vg-ubuntu--lv 253:0    0   31G  0 lvm  /
sdb                         8:16   0    5G  0 disk
```

**2.2 create new partition**:
```bash
# command:
sudo fdisk /dev/sdb

Command (m for help): n
Partition type
   p   primary (0 primary, 0 extended, 4 free)
   e   extended (container for logical partitions)
Select (default p): p
Partition number (1-4, default 1): 1
First sector (2048-10485759, default 2048): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-10485759, default 10485759): 10485759

Created a new partition 1 of type 'Linux' and of size 5 GiB.

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
```

**2.3 recheck the partition**:
```bash
deploy@worker1:~$ sudo lsblk --output NAME,FSTYPE,LABEL,UUID,SIZE,MODE
NAME                      FSTYPE      LABEL UUID                                    SIZE MODE
loop0                     squashfs                                                 63.7M brw-rw----
loop1                     squashfs                                                 63.9M brw-rw----
loop2                     squashfs                                                   87M brw-rw----
loop3                     squashfs                                                 89.4M brw-rw----
loop4                     squashfs                                                 40.4M brw-rw----
sda                                                                                  64G brw-rw----
├─sda1                                                                                1M brw-rw----
├─sda2                    ext4              5e5081dd-7961-4507-a56b-471be7d54906      2G brw-rw----
└─sda3                    LVM2_member       m3QGCy-g9uk-Grbh-Qiqr-LHkW-nzwQ-o7uyIc   62G brw-rw----
  └─ubuntu--vg-ubuntu--lv ext4              4b6c3454-ca06-4504-8f29-d1ed1407bb55     31G brw-rw----
sdb                                                                                   5G brw-rw----
└─sdb1                                                                                5G brw-rw----
```

**2.4 create `longhorn data` and mounting to new volume**
```bash
# command:
sudo mkdir -p /data/longhorn
sudo mkfs.ext4 /dev/sdb1
sudo mount /dev/sdb1 /data/longhorn

# command for check 
df -h

# result
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              392M  4.6M  387M   2% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   31G  8.3G   21G  29% /
tmpfs                              2.0G     0  2.0G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G   84M  1.8G   5% /boot
...
/dev/sdb1                          4.9G   24K  4.6G   1% /data/longhorn
```

**2.5 make permanent mounting**
```bash
# command:
cat << EOF | sudo tee -a /etc/fstab
/dev/sdb1  /data/longhorn ext4 defaults 0 2
EOF
```

### 3. Add longhorn disk:
```bash
# command:
k get lhn  | k get nodes.longhorn.io

# result
NAME      READY   ALLOWSCHEDULING   SCHEDULABLE   AGE
worker1   True    true              True          98m
worker2   True    true              True          162m

# edit longhorn node
k edit lhn  worker2

# yaml
apiVersion: longhorn.io/v1beta2
kind: Node
metadata:
  creationTimestamp: "2025-03-21T15:02:32Z"
  finalizers:
  - longhorn.io
  generation: 1
  name: worker2
  namespace: longhorn
  resourceVersion: "81536"
  uid: 0b9e5859-8c08-4519-b7ae-90222799e5d2
spec:
  allowScheduling: true
  disks:
    default-disk-b9e545c451fe01de:
      allowScheduling: false # disable schedule on root
      diskType: filesystem
      evictionRequested: false
      path: /var/lib/longhorn/
      storageReserved: 9772464537
      tags: []
    disk2-longhorn-data: # add new disk
      allowScheduling: true
      diskType: filesystem
      evictionRequested: false
      path: /data/longhorn/
      storageReserved: 0
      tags: []
  evictionRequested: false
  instanceManagerCPURequest: 0
  name: worker2
  tags: []
```

## IV. Delete longhorn volume and data

### 1. get longhorn volume:
```bash
# command
k -n longhorn get replicas.longhorn.io -o wide

# result
NAME                                                  DATA ENGINE   STATE     NODE      DISK                                   INSTANCEMANAGER   IMAGE   AGE
pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2-r-17d2367e   v1            stopped   worker2   5fb92b3c-67b2-4bad-8bc8-aafc05aae2f1                             10h
pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2-r-bf3ab4cd   v1            stopped   worker2   5fb92b3c-67b2-4bad-8bc8-aafc05aae2f1                             10h
pvc-953517e1-09ed-4c58-8803-f2fd0c17fdf3-r-5246b7a2   v1            stopped   worker2   5fb92b3c-67b2-4bad-8bc8-aafc05aae2f1                             10h
pvc-953517e1-09ed-4c58-8803-f2fd0c17fdf3-r-6859282c   v1            stopped   worker2   5fb92b3c-67b2-4bad-8bc8-aafc05aae2f1                             10h
pvc-baf2da19-48c5-410c-9874-658021ec9521-r-4435f667   v1            stopped   worker2   5fb92b3c-67b2-4bad-8bc8-aafc05aae2f1                             10h
pvc-baf2da19-48c5-410c-9874-658021ec9521-r-ffbdbd30   v1            stopped   worker1   300ea7bb-f350-4414-b0dc-e53139c534df                             10h
```

### 2. check longhorn replica: 

let's check `longhornnode`, `dataDirectoryName`, `diskPath`
```bash
# command
k get replicas.longhorn.io pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2-r-17d2367e -n longhorn -o yaml

# result
apiVersion: longhorn.io/v1beta2
kind: Replica
metadata:
  creationTimestamp: "2025-03-23T05:53:57Z"
  finalizers:
  - longhorn.io
  generation: 8
  labels:
    longhorn.io/backing-image: ""
    longhorndiskuuid: 5fb92b3c-67b2-4bad-8bc8-aafc05aae2f1
    longhornnode: worker2
    longhornvolume: pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2
spec:
  active: true
  backendStoreDriver: ""
  backingImage: ""
  dataDirectoryName: pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2-1836469c
  dataEngine: v1
  desireState: stopped
  diskPath: /var/lib/longhorn/
  volumeName: pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2
  volumeSize: "3221225472"
```

### 3. check the size:
```bash
# command:
sudo du -h --max-depth=1 /var/lib/longhorn/replicas/

# result
114M	/var/lib/longhorn/replicas/pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2-ddacdd06
114M	/var/lib/longhorn/replicas/pvc-953517e1-09ed-4c58-8803-f2fd0c17fdf3-b5301ad5
114M	/var/lib/longhorn/replicas/pvc-953517e1-09ed-4c58-8803-f2fd0c17fdf3-648231b9
114M	/var/lib/longhorn/replicas/pvc-baf2da19-48c5-410c-9874-658021ec9521-0ed8b9fc
114M	/var/lib/longhorn/replicas/pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2-1836469c
569M	/var/lib/longhorn/replicas/
```

### 4. delete `longhorn volume`
```bash
# command:
k delete volumes pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2 pvc-953517e1-09ed-4c58-8803-f2fd0c17fdf3 pvc-baf2da19-48c5-410c-9874-658021ec9521 -n longhorn

# result
volume.longhorn.io "pvc-205d9247-40e2-4915-b4b1-1beaf44afdb2" deleted
volume.longhorn.io "pvc-953517e1-09ed-4c58-8803-f2fd0c17fdf3" deleted
volume.longhorn.io "pvc-baf2da19-48c5-410c-9874-658021ec9521" deleted
```

### 5. check the size again:
```bash
sudo du -h --max-depth=1 /var/lib/longhorn/replicas/
4.0K	/var/lib/longhorn/replicas/
```