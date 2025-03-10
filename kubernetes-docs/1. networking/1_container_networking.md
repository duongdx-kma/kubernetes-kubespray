# Container networking:

## I. `Network Namespace` and `Virtual Ethernet(veth)` Interface

```
Network namespace provide isolation of the system resource associated with networking

- Networking devices
- Ipv4 and IPv6 protocol stack
- Firewall rules
- Port numbers (sockets)
- Veth devices are built as pairs of connected virtual ethernet interfaces and can be thought of as virtual patch cable.
```

## II. hand-ons create `network namespace` and `Virtual Ethernet`:

### 1. node_1: `node_1.sh`
```bash
#!/bin/bash

# https://github.com/gary-RR/myYouTube_video_container_networking/blob/main/part1-bridged-network.sh#L59
# namespace env
NS_1="NS1" # container 1
NS_IP1="172.161.0.10" # container 1

NS_2="NS2" # container 2
NS_IP2="172.161.0.11" # container 2

# Bridge env
BRIDGE_NAME="br100"
BRIDGE_SUBNET="172.161.0.0/24"
BRIDGE_IP="172.161.0.1"

# node_1 env
NODE_1_IP="192.168.63.15"
NODE_1_ETH="eth1"


# Destination is node_2:
NODE_2_IP="192.168.63.16"
NODE_2_NS_IP1="172.161.1.10" # container 1
NODE_2_NS_IP2="172.161.1.11" # container 2
NODE_2_BRIDGE_IP="172.161.1.1"
NODE_2_BRIDGE_SUBNET="172.161.1.0/24"

echo "### 1. create the namespace"
sudo ip netns add $NS_1
sudo ip netns add $NS_2

echo "### 2. show namespace created"
sudo ip netns show

echo "### 3. create Veth pairs"
sudo ip link add veth10 type veth peer name veth11
sudo ip link add veth20 type veth peer name veth21

echo "### 4. show Veth created"
sudo ip link show type veth

echo "### 5. Adding the veth pairs to the namespaces"
sudo ip link set veth11 netns $NS_1
sudo ip link set veth21 netns $NS_2

echo "### 6. Configuring the interfaces in the network namespaces with IP address"
sudo ip netns exec $NS_1 ip addr add $NS_IP1/24 dev veth11
sudo ip netns exec $NS_2 ip addr add $NS_IP2/24 dev veth21

echo "### 7. Enabling the interfaces inside the network namespaces"
sudo ip netns exec $NS_1 ip link set dev veth11 up
sudo ip netns exec $NS_2 ip link set dev veth21 up

echo "### 8. Creating the bridge"
sudo ip link add $BRIDGE_NAME type bridge
sudo ip link show type bridge

echo "### 9. Assigning the IP address to the bridge"
sudo ip addr add $BRIDGE_IP/24 dev $BRIDGE_NAME

echo "### 10. Adding the network namespaces interfaces to the bridge"
sudo ip link set dev veth10 master $BRIDGE_NAME
sudo ip link set dev veth20 master $BRIDGE_NAME

echo "### 11. Enabling the bridge"
sudo ip link set dev $BRIDGE_NAME up

echo "### 12. Enabling the interfaces connected to the bridge"
sudo ip link set dev veth10 up
sudo ip link set dev veth20 up

echo "### 13. Setting the loopback interfaces in the network namespaces"
sudo ip netns exec $NS_1 ip link set lo up
sudo ip netns exec $NS_2 ip link set lo up
sudo ip netns exec $NS_1 ip a
sudo ip netns exec $NS_2 ip a

echo "### 14. Setting the default route in the network namespaces"
sudo ip netns exec $NS_1 ip route add default via $BRIDGE_IP dev veth11
sudo ip netns exec $NS_2 ip route add default via $BRIDGE_IP dev veth21

# ------------------- NODE Setup --------------------- #

echo "### 15. Setting the route on the node to reach the network namespaces on the other node"
sudo ip route add $NODE_2_BRIDGE_SUBNET via $NODE_2_IP dev $NODE_1_ETH

echo "### 16. Enables IP forwarding on the node"
sudo sysctl -w net.ipv4.ip_forward=1
```

### 2. node_2: `node_2.sh`
```bash
/bin/bash
# namespace env
NS_1="NS1" # container 1
NS_IP1="172.161.1.10" # container 1

NS_2="NS2" # container 2
NS_IP2="172.161.1.11" # container 2

# Bridge env
BRIDGE_NAME="br100"
BRIDGE_SUBNET="172.161.1.0/24"
BRIDGE_IP="172.161.1.1"

# node_2 env
NODE_2_IP="192.168.63.16"
NODE_2_ETH="eth1"


# Destination is node_1:
NODE_1_IP="192.168.63.15"
NODE_1_NS_IP1="172.161.0.10" # container 1
NODE_1_NS_IP2="172.161.0.11" # container 2
NODE_1_BRIDGE_IP="172.161.0.1"
NODE_1_BRIDGE_SUBNET="172.161.0.0/24"

echo "### 1. create the namespace"
sudo ip netns add $NS_1
sudo ip netns add $NS_2

echo "### 2. show namespace created"
sudo ip netns show

echo "### 3. create Veth pairs"
sudo ip link add veth10 type veth peer name veth11
sudo ip link add veth20 type veth peer name veth21

echo "### 4. show Veth created"
sudo ip link show type veth

echo "### 5. Adding the veth pairs to the namespaces"
sudo ip link set veth11 netns $NS_1
sudo ip link set veth21 netns $NS_2

echo "### 6. Configuring the interfaces in the network namespaces with IP address"
sudo ip netns exec $NS_1 ip addr add $NS_IP1/24 dev veth11
sudo ip netns exec $NS_2 ip addr add $NS_IP2/24 dev veth21

echo "### 7. Enabling the interfaces inside the network namespaces"
sudo ip netns exec $NS_1 ip link set dev veth11 up
sudo ip netns exec $NS_2 ip link set dev veth21 up

echo "### 8. Creating the bridge"
sudo ip link add $BRIDGE_NAME type bridge
sudo ip link show type bridge

echo "### 9. Assigning the IP address to the bridge"
sudo ip addr add $BRIDGE_IP/24 dev $BRIDGE_NAME

echo "### 10. Adding the network namespaces interfaces to the bridge"
sudo ip link set dev veth10 master $BRIDGE_NAME
sudo ip link set dev veth20 master $BRIDGE_NAME

echo "### 11. Enabling the bridge"
sudo ip link set dev $BRIDGE_NAME up

echo "### 12. Enabling the interfaces connected to the bridge"
sudo ip link set dev veth10 up
sudo ip link set dev veth20 up

echo "### 13. Setting the loopback interfaces in the network namespaces"
sudo ip netns exec $NS_1 ip link set lo up
sudo ip netns exec $NS_2 ip link set lo up
sudo ip netns exec $NS_1 ip a
sudo ip netns exec $NS_2 ip a

echo "### 14. Setting the default route in the network namespaces"
sudo ip netns exec $NS_1 ip route add default via $BRIDGE_IP dev veth11
sudo ip netns exec $NS_2 ip route add default via $BRIDGE_IP dev veth21

# ------------------- NODE Setup --------------------- #

echo "### 15. Setting the route on the node to reach the network namespaces on the other node"
sudo ip route add $NODE_1_BRIDGE_SUBNET via $NODE_1_IP dev $NODE_2_ETH

echo "### 16. Enables IP forwarding on the node"
sudo sysctl -w net.ipv4.ip_forward=1
```

### 3. Linux network `ARP` and `FDP`
```
Tuyệt vời! Đây là câu hỏi rất hay, nhất là khi bạn đang làm việc với container networking ở mức low-level như dùng `ip netns`, `veth`, và `bridge`. Mình sẽ giải thích kỹ:

---

## 🧠 1. **ARP Table (Address Resolution Protocol Table)**

### 📌 Định nghĩa:
`ARP table` là một bảng ánh xạ giữa **IP address** và **MAC address**. Nó giúp một host biết **MAC** nào tương ứng với **IP** nào trong cùng subnet để gửi gói dữ liệu đi.

> 💡 Khi container hoặc host cần gửi gói đến IP trong cùng subnet, nó dùng ARP để hỏi: "MAC của IP đó là gì?"

### 📋 Ví dụ:
Bạn có container `172.161.0.10`, khi ping tới `172.161.0.1`, kernel sẽ:
- Kiểm tra ARP table.
- Nếu chưa có, sẽ gửi **ARP Request** ra bridge.
- Bridge trả lại **ARP Reply**, ví dụ:
  ```
  172.161.0.1 is-at aa:bb:cc:dd:ee:ff
  ```
- Sau đó lưu lại vào ARP Table.

### 🔍 Kiểm tra ARP Table:
```bash
ip neigh
```

---

## 📘 2. **FDB (Forwarding Database)**

### 📌 Định nghĩa:
`FDB` là bảng ánh xạ **MAC address** đến **bridge port**. Nó được dùng trong **Linux bridge** để biết nên **forward frame ra cổng nào** khi bridge nhận một gói Ethernet.

> 💡 Bạn có thể tưởng tượng FDB giống như "switch table" trong một switch vật lý.

### 🧱 Vai trò trong container:
Khi bạn tạo `veth` và nối vào một `Linux bridge`:
- Mỗi `veth` (đầu gắn vào bridge) là một "port".
- Khi một frame từ MAC `aa:bb:cc:dd:ee:ff` gửi qua, bridge sẽ học rằng MAC đó nằm ở port nào.
- Lần sau, nó sẽ gửi frame tới đúng cổng veth đó thay vì broadcast.

### 🔍 Kiểm tra FDB:
```bash
bridge fdb show
```

---

## 🔄 So sánh nhanh

| Thành phần | ARP Table | FDB (Forwarding DB) |
|------------|-----------|----------------------|
| Dùng bởi | Host / Container | Linux Bridge |
| Mục đích | IP → MAC | MAC → Bridge Port |
| Giao thức | Lớp 3 (IP) | Lớp 2 (MAC) |
| Lệnh kiểm tra | `ip neigh` | `bridge fdb show` |
| Khi nào tạo? | Khi cần gửi IP trong cùng subnet | Khi bridge học MAC từ traffic |

---

## 📌 Tình huống cụ thể bạn đang làm:
Giả sử bạn có:

- `NS1 (172.161.0.10)` ↔ `veth` ↔ `br100`
- `br100` nối `veth` của NS2 hoặc default route

Thì:
- `NS1` có ARP Table để map IP (172.161.0.1) → MAC.
- `br100` có FDB để map MAC (vd. của NS1) → port (veth11).

---

Nếu bạn muốn **thực hành thấy rõ hơn**, mình có thể giúp bạn tạo 2 namespace và quan sát từng bước ARP & FDB bằng `tcpdump`, `ip neigh`, `bridge fdb show`. Bạn cần không?
```

```
Câu hỏi trên StackExchange bạn đưa ra:

> **"Who owns the ARP table and FDB in the context of a Linux network namespace?"**

là một câu hỏi rất hay – nó yêu cầu hiểu sâu về **Linux network namespaces**, và cách **ARP Table** và **FDB (Forwarding Database)** hoạt động bên trong đó. Dưới đây là phần giải thích chi tiết theo phong cách của một sysadmin / network engineer 👇

---

## 🧠 Trước tiên, hiểu sơ lược:

### 1. **Network Namespace (netns)**

- Là một không gian độc lập về mặt networking: mỗi `netns` có thể có **interface riêng**, **route riêng**, **ARP Table riêng**.
- Giống như một máy ảo cực nhẹ về mạng: bên trong có thể `ip a`, `ip route`, `ip neigh`, v.v.

---

## 🔍 Câu hỏi đặt ra là:

- **"ARP table và FDB nằm ở đâu? Ai sở hữu?"**
- Cụ thể: nếu bạn tạo một `bridge` trong `default namespace`, rồi kết nối các `veth` từ container (namespace) khác vào đó – thì:
  - ARP table nằm ở đâu?
  - FDB nằm ở đâu?
  - Có mỗi namespace có một FDB riêng?

---

## ✅ Câu trả lời chính xác:

### 🔹 **ARP Table**:

- Mỗi **network namespace** có **một ARP table riêng**.
- Bạn chạy `ip neigh` trong namespace nào → sẽ chỉ thấy các ARP entry của chính namespace đó.
- Khi một container / netns gửi gói đến IP nào đó trong cùng subnet, nó dùng ARP để tìm MAC. Bảng ánh xạ IP → MAC nằm **trong namespace của container đó**.

### 🔹 **FDB (Forwarding Database)**:

- **FDB là thuộc tính của bridge**, và **bridge luôn tồn tại trong namespace nơi nó được tạo**.
- Thông thường, nếu bạn tạo bridge trong **default namespace**, thì:
  - **FDB cũng nằm trong default namespace.**
  - Dù container (netns khác) nối vào bridge bằng veth pair, bridge vẫn giữ **MAC → port (veth)** mapping trong FDB của chính nó.

---

## 💡 Một ví dụ cụ thể:

1. Bạn tạo một bridge `br0` trong **default namespace**.

2. Bạn có `NS1` và `NS2`, mỗi cái chứa một đầu `veth` kết nối vào `br0` qua veth peer:

   ```bash
   ip netns add ns1
   ip link add veth1 type veth peer name veth1-br
   ip link set veth1 netns ns1
   ip link set veth1-br master br0
   ```

3. FDB nằm trong default namespace – bạn thấy bằng:

   ```bash
   bridge fdb show
   ```

4. Nhưng trong `ns1`, nếu bạn chạy `ip neigh`, bạn sẽ thấy ARP Table của `ns1`.

---

## 🔄 Tóm lại:

| Thành phần | Chủ sở hữu | Tồn tại trong namespace |
|------------|------------|-------------------------|
| **ARP Table** | Namespace | Có riêng trong mỗi netns |
| **FDB** | Linux Bridge | Trong netns nơi bridge được tạo |

> 🧠 **Điểm quan trọng**: nếu bạn muốn container / namespace học MAC thì cần nhìn FDB của bridge **ở default namespace**, còn nếu bạn muốn biết IP của ai là ai → xem ARP trong netns.

---

Nếu bạn muốn mình dựng mô hình đơn giản (script `ip netns`) để minh họa rõ điều này, mình sẵn sàng hỗ trợ 💪.
```


```
Rất tốt! Bạn đã cung cấp thông tin hoàn chỉnh để **minh hoạ chính xác mối quan hệ giữa ARP Table và FDB** trong bối cảnh `br100`, `NS1`, và `NS2`.

---

## 📦 **Mô hình hiện tại của bạn có thể được mô tả như sau:**

```
Namespace "NS1"     Namespace "NS2"
+-------------+     +-------------+
| veth11      |     | veth21      |
| MAC: 22:04..|     | MAC: 6a:ed..|
| IP: 172.161.0.10  | IP: 172.161.0.11 |
+------|------+     +------|------+
       |                   |
       |                   |
       |                   |
    +-----------------------------+
    |       Bridge: br100        |
    |       (Default Namespace)  |
    +-----------------------------+
```

---

## 🔹 1. **Thông tin từ `ip netns` (bên trong NS1 và NS2):**

Bạn đã xác nhận rằng:
- `veth11` trong `NS1` có **MAC**: `22:04:65:2a:9d:54` → IP: `172.161.0.10`
- `veth21` trong `NS2` có **MAC**: `6a:ed:ad:ad:d8:94` → IP: `172.161.0.11`

---

## 🔹 2. **`ip neigh` trên host (default namespace):**

```bash
ip neigh show dev br100
172.161.0.10 lladdr 22:04:65:2a:9d:54 STALE
172.161.0.11 lladdr 6a:ed:ad:ad:d8:94 STALE
```

💡 Đây là **ARP table** của **host**, gắn với interface `br100`. Mỗi entry ánh xạ:
- IP → MAC (giúp gửi packet ở tầng 2)
- Entry này **do host "học được"** khi gói tin đi qua hoặc được sinh ra bởi các namespace

> 📌 **Lưu ý:** nếu bạn chạy `ip netns exec $NS_1 ip neigh`, bạn sẽ thấy ARP riêng của `NS1`, thường chỉ chứa các IP mà `NS1` từng gửi packet đến.

---

## 🔹 3. **`bridge fdb show dev br100` trên host:**

```bash
bridge fdb show dev br100
...
22:04:65:2a:9d:54 vlan 1 master br100 permanent  <-- veth11
6a:ed:ad:ad:d8:94 vlan 1 master br100 permanent  <-- veth21
```

✅ Đây là **FDB table** của `br100`. Mỗi entry ánh xạ:
- **MAC → interface** (veth)
- Khi gói tin đến bridge với MAC đích là `6a:ed:...`, bridge sẽ **forward đến interface** tương ứng với veth21.

---

## 🧠 Tổng kết:

| Thành phần | Nằm ở đâu | Dữ liệu chứa | Nguồn gốc |
|------------|-----------|---------------|-----------|
| **ARP Table (`ip neigh`)** | Trong mỗi namespace riêng biệt | IP → MAC | Học qua ARP request/reply |
| **FDB (`bridge fdb`)** | Trong bridge (namespace chứa bridge – thường là default) | MAC → veth | Học động hoặc thêm thủ công |

---

## ✅ Câu hỏi thường gặp:

### 🔸 Vì sao `bridge` cần FDB?

→ Để biết **gói Ethernet có MAC đích A thì forward vào veth nào**.

---

### 🔸 Vì sao `NS1` có thể ping `NS2`?

→ Vì:

- NS1 dùng ARP để tìm MAC của IP `172.161.0.11` (MAC: `6a:ed:...`)
- Gửi gói ra veth11 → vào bridge `br100`
- Bridge dùng FDB: MAC `6a:ed:...` → forward ra veth21 → NS2 nhận

---

### 🔸 `ip neigh` và `bridge fdb` có liên quan nhau không?

→ Không hẳn:
- `ip neigh` là **ARP** (IP-layer)
- `bridge fdb` là **L2 MAC forwarding**

Chúng hoạt động ở các lớp khác nhau, **hợp tác để gói tin tới đúng nơi**.

---

Nếu bạn muốn mình giúp bạn visualize mô hình bằng hình vẽ ASCII hoặc sơ đồ veth–bridge thì nói nhé 😄
```

```
Cảm ơn bạn đã phản hồi chính xác! Bạn hoàn toàn đúng — ta **không thấy các địa chỉ MAC của veth11 (22:04:65:2a:9d:54)** hay **veth21 (6a:ed:ad:ad:d8:94)** xuất hiện trong output của:

```bash
bridge fdb show dev br100
```

Vậy chúng ta cùng làm rõ lại từ đầu nhé, với giải thích **đúng và đầy đủ hơn** về FDB trong bối cảnh container networking, đồng thời phân tích kết quả của bạn.

---

## ✅ **FDB trong Bridge là gì?**

### 🔸 Khái niệm:
FDB (Forwarding Database) là bảng **MAC → cổng ra (port/interface)** của bridge. Mỗi khi bridge thấy một frame có địa chỉ MAC nguồn `A` đi vào qua cổng `vethX`, nó sẽ **học được** rằng MAC `A` nằm ở interface `vethX`. Khi có frame đích đến `A`, bridge sẽ forward đúng ra interface `vethX`.

---

## 🎯 **Vấn đề bạn gặp: Vì sao FDB không có MAC của veth11/veth21?**

Bạn kỳ vọng thấy MAC `22:04:65:2a:9d:54` (veth11 – NS1) và `6a:ed:ad:ad:d8:94` (veth21 – NS2) trong FDB của `br100`. Nhưng không thấy.

### 📌 Giải thích:
1. FDB **chỉ chứa các entry MAC → port** khi bridge **thật sự "thấy" một frame có MAC đó**.
2. Nếu bạn **chưa truyền frame từ các namespace**, hoặc frame đi ra nhưng **bridge không cần học (vì không dùng MAC đó để reply)**, thì FDB sẽ **chưa có entry tương ứng**.
3. Hoặc bridge đang dùng chế độ **flooding mặc định** nếu chưa học được MAC.

---

## 🔍 Nhưng rõ ràng bạn đã chạy `ping` từ `NS1 ↔ NS2`! Tức là frame đã được truyền rồi, đúng không?

### ❗ Vấn đề có thể nằm ở đâu?

#### 🧪 1. Kiểm tra lại chính xác:
Bạn có thể chạy lại `bridge fdb show dev br100` **ngay sau khi chạy `ping` từ NS1 đến NS2**, xem FDB có cập nhật hay không.

#### 🧪 2. Có thể bridge đang dùng MAC khác để forwarding:
Bạn kiểm tra thấy MAC `3a:9d:4a:b7:bc:72` xuất hiện 2 lần:

```bash
3a:9d:4a:b7:bc:72 vlan 1 master br100 permanent
3a:9d:4a:b7:bc:72 master br100 permanent
```

→ Đây là một địa chỉ **có thể thuộc veth pair đầu bên host**, không phải là veth11/21 bên trong netns.

Thử lệnh sau để xem MAC của interface gắn với `br100`:

```bash
ip link show master br100
```

→ Nó sẽ liệt kê toàn bộ port/interface gắn vào `br100`, bạn sẽ dễ thấy interface nào có MAC là `3a:9d:4a:b7:bc:72`.

---

## 🧠 Tổng kết lại:

| Loại | Mục tiêu | Có chứa gì | Ở đâu |
|------|----------|------------|-------|
| **ARP Table (`ip neigh`)** | Tìm MAC từ IP | IP → MAC | Trong mỗi netns (và default netns) |
| **FDB (`bridge fdb`)** | Tìm interface từ MAC | MAC → port (interface) | Trong bridge (`br100`) ở default namespace |

🔁 **FDB học được khi:**
- Có frame ra vào bridge, và
- MAC nguồn không phải là "self" hoặc multicast, và
- Frame đi qua MAC riêng biệt của các veth pair (host side)

---

## ✅ Đề xuất kiểm tra thêm

### 1. Liệt kê các interface gắn với br100:

```bash
bridge link
```

### 2. Xem rõ MAC của từng interface:

```bash
ip -br link show
```

### 3. Chạy `bridge fdb` **sau khi ping giữa NS1 và NS2** để xác thực FDB đã học.

---

Nếu bạn muốn, mình có thể giúp bạn **viết một đoạn script nhỏ để test tự động** quá trình: ping từ NS1 ↔ NS2 và dump lại ARP + FDB kèm comment phân tích. Bạn có cần không?
```