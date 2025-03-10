NUM_MASTER_NODE = 3 # add standby master - recommend 3, 5, 7 master_node
NUM_WORKER_NODE = 2
NUM_PROXY_NODE = 1

IP_NW = "192.168.56."
MASTER_IP_START = 10
NODE_IP_START = 15
PROXY_IP_START = 30

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = false

  (1..NUM_PROXY_NODE).each do |i|
    config.vm.define "haproxy0#{i}" do |node|
      node.vm.provider "virtualbox" do |vb|
        vb.name = "haproxy0#{i}"
        vb.memory = 1024
        vb.cpus = 1
      end
      node.vm.hostname = "haproxy0#{i}"
      node.vm.network :private_network, ip: IP_NW + "#{PROXY_IP_START + i}"
      node.vm.network "forwarded_port", guest: 22, host: "#{1607 + i}"
      node.vm.provision "setup-dns", type: "shell", :path => "./update-dns.sh"
    end
  end

  # provision master node
  (1..NUM_MASTER_NODE).each do |i|
	  config.vm.define "master#{i}" do |node|
      node.vm.provider "virtualbox" do |vb|
        vb.name = "master#{i}"
        vb.memory = 1024
        vb.cpus = 1
      end
      node.vm.hostname = "master#{i}"
      #manifests folder
      node.vm.network :private_network, ip: IP_NW + "#{MASTER_IP_START + i}"
      node.vm.network "forwarded_port", guest: 22, host: "#{2780 + i}"
      node.vm.provision "setup-dns", type: "shell", :path => "./update-dns.sh"
	  end
  end

  # Provision Worker Nodes
  (1..NUM_WORKER_NODE).each do |i|
    config.vm.define "worker#{i}" do |node|
      node.vm.provider "virtualbox" do |vb|
          vb.name = "worker#{i}"
          vb.memory = 1024
          vb.cpus = 1
      end
      node.vm.hostname = "worker#{i}"
      node.vm.network :private_network, ip: IP_NW + "#{NODE_IP_START + i}"
      node.vm.network "forwarded_port", guest: 22, host: "#{2790 + i}"
      node.vm.provision "setup-dns", type: "shell", :path => "./update-dns.sh"
    end
  end

  config.vm.provision "setup-deployment-user", type: "shell" do |s|
      ssh_pub_key = File.readlines("./client.pem.pub").first.strip
      s.inline = <<-SHELL
          # create deploy user
          useradd -s /bin/bash -d /home/deploy/ -m -G sudo deploy
          echo 'deploy ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
          mkdir -p /home/deploy/.ssh && chown -R deploy /home/deploy/.ssh
          echo #{ssh_pub_key} >> /home/deploy/.ssh/authorized_keys
          chown -R deploy /home/deploy/.ssh/authorized_keys
          # config timezone
          timedatectl set-timezone Asia/Ho_Chi_Minh
      SHELL
  end
end
