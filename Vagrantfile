# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

# VM Configuration based on PLAN.md
$vm_config = {
  "tka-n1" => {
    ip: "192.168.56.10",
    cpus: 2,
    memory: 4096,
    role: "manager-nginx-redis"
  },
  "tka-n2" => {
    ip: "192.168.56.11",
    cpus: 2,
    memory: 2048,
    role: "worker-flask"
  },
  "tka-n3" => {
    ip: "192.168.56.12",
    cpus: 2,
    memory: 2048,
    role: "worker-flask"
  },
  "tka-n4" => {
    ip: "192.168.56.13",
    cpus: 1,
    memory: 2048,
    role: "mongodb"
  },
  "tka-locust" => {
    ip: "192.168.56.14",
    cpus: 1,
    memory: 1024,
    role: "locust-tester"
  }
}

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "generic/ubuntu2204"
  config.vm.box_check_update = false
  
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.storage_pool_name = "default"
  end

  $vm_config.each do |name, cfg|
    config.vm.define name do |node|
      node.vm.hostname = name
      
      node.vm.network :private_network, ip: cfg[:ip], libvirt__network_name: "tka-private"
      
      if name == "tka-n1"
        node.vm.network :forwarded_port, guest: 80, host: 8080, auto_correct: true
      end
      
      node.vm.provider :libvirt do |lv|
        lv.cpus = cfg[:cpus]
        lv.memory = cfg[:memory]
        lv.cpu_mode = "host-passthrough"
      end
      
      node.vm.provision "shell", inline: <<-SHELL
        echo "#{name} (#{cfg[:role]}) provisioned with #{cfg[:cpus]} CPUs, #{cfg[:memory]}MB RAM"
        apt-get update -qq
        apt-get install -y -qq docker.io docker-compose > /dev/null 2>&1
        systemctl enable docker
        systemctl start docker
        usermod -aG docker vagrant
        echo "Docker installed on #{name}"
      SHELL
    end
  end
end
