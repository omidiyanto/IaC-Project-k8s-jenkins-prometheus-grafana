terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.1-rc3"
    }
  }
}

resource "proxmox_vm_qemu" "k8s-master" {
  name        = "k8s-master"
  target_node = "proxmox"
  vmid        = 300
  clone       = "ubuntu-template"
  full_clone  = true

  ciuser     = var.ci_user
  cipassword = var.ci_password
  sshkeys    = file(var.ci_ssh_public_key)

  agent      = 1
  cores      = 4
  memory     = 8192
  os_type    = "cloud-init"
  bootdisk   = "scsi0"
  scsihw     = "virtio-scsi-pci"

  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "local"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 10
          storage = "local"
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot     = "order=scsi0"
  ipconfig0 = "ip=dhcp"
  
  lifecycle {
    ignore_changes = [ 
      network
    ]
  }
}

resource "proxmox_vm_qemu" "k8s-workers" {
  count       = var.vm_count
  name        = "k8s-worker-${count.index + 1}"
  target_node = "proxmox"
  vmid        = 301 + count.index
  clone       = "ubuntu-template"
  full_clone  = true

  ciuser     = var.ci_user
  cipassword = var.ci_password
  sshkeys    = file(var.ci_ssh_public_key)

  agent      = 1
  cores      = 4
  memory     = 4096
  os_type    = "cloud-init"
  bootdisk   = "scsi0"
  scsihw     = "virtio-scsi-pci"

  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "local"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 10
          storage = "local"
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot     = "order=scsi0"
  ipconfig0 = "ip=dhcp"
  
  lifecycle {
    ignore_changes = [ 
      network
    ]
  }
}

resource "proxmox_vm_qemu" "jenkins-server" {
  name        = "jenkins-server"
  target_node = "proxmox"
  vmid        = 303
  clone       = "ubuntu-template"
  full_clone  = true

  ciuser     = var.ci_user
  cipassword = var.ci_password
  sshkeys    = file(var.ci_ssh_public_key)

  agent      = 1
  cores      = 4
  memory     = 8192
  os_type    = "cloud-init"
  bootdisk   = "scsi0"
  scsihw     = "virtio-scsi-pci"

  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "local"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 20
          storage = "local"
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot     = "order=scsi0"
  ipconfig0 = "ip=dhcp"
  
  lifecycle {
    ignore_changes = [ 
      network
    ]
  }
}

resource "proxmox_vm_qemu" "monitoring-server" {
  name        = "monitoring-server"
  target_node = "proxmox"
  vmid        = 304
  clone       = "ubuntu-template"
  full_clone  = true

  ciuser     = var.ci_user
  cipassword = var.ci_password
  sshkeys    = file(var.ci_ssh_public_key)

  agent      = 1
  cores      = 2
  memory     = 4096
  os_type    = "cloud-init"
  bootdisk   = "scsi0"
  scsihw     = "virtio-scsi-pci"

  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "local"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 10
          storage = "local"
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot     = "order=scsi0"
  ipconfig0 = "ip=dhcp"
  
  lifecycle {
    ignore_changes = [ 
      network
    ]
  }
}

output "vm_info" {
  value = {
    master = {
      hostname = proxmox_vm_qemu.k8s-master.name
      ip_addr  = proxmox_vm_qemu.k8s-master.default_ipv4_address
    },
    workers = [
      for vm in proxmox_vm_qemu.k8s-workers : {
        hostname = vm.name
        ip_addr  = vm.default_ipv4_address
      }
    ],
    jenkins_server = {
      hostname = proxmox_vm_qemu.jenkins-server.name
      ip_addr  = proxmox_vm_qemu.jenkins-server.default_ipv4_address
    },
    monitoring_server = {
      hostname = proxmox_vm_qemu.monitoring-server.name
      ip_addr  = proxmox_vm_qemu.monitoring-server.default_ipv4_address
    }
  }
}

resource "local_file" "create_ansible_inventory" {
  depends_on = [
    proxmox_vm_qemu.k8s-master,
    proxmox_vm_qemu.k8s-workers,
    proxmox_vm_qemu.jenkins-server,
    proxmox_vm_qemu.monitoring-server
  ]

  content = <<EOT
[master-node]
${proxmox_vm_qemu.k8s-master.default_ipv4_address}

[worker-node]
${join("\n", [for worker in proxmox_vm_qemu.k8s-workers : worker.default_ipv4_address])}

[jenkins-server]
${proxmox_vm_qemu.jenkins-server.default_ipv4_address}

[monitoring-server]
${proxmox_vm_qemu.monitoring-server.default_ipv4_address}
EOT

  filename = "./inventory.ini"
}

resource "null_resource" "update_hosts_file" {
  depends_on = [
    local_file.create_ansible_inventory
  ]

  provisioner "local-exec" {
    command = <<EOT
      # Membuat backup file hosts sebelum mengganti
      cp /etc/hosts /etc/hosts.backup

      # Mengganti atau menambah entri hostname dengan IP sesuai
      echo "Updating /etc/hosts..."
      
      # Membersihkan entri lama terkait dengan k8s-master, k8s-worker, jenkins-server, monitoring-server
      sed -i '/k8s-master/d' /etc/hosts
      sed -i '/k8s-worker/d' /etc/hosts
      sed -i '/jenkins-server/d' /etc/hosts
      sed -i '/monitoring-server/d' /etc/hosts

      # Menambahkan entri baru sesuai IP dan hostname
      echo "${proxmox_vm_qemu.k8s-master.default_ipv4_address} k8s-master" >> /etc/hosts
      i=1
      for worker in ${join(" ", [for worker in proxmox_vm_qemu.k8s-workers : worker.default_ipv4_address])}; do
        echo "$worker k8s-worker-$i" >> /etc/hosts
        i=$((i + 1))
      done
      echo "${proxmox_vm_qemu.jenkins-server.default_ipv4_address} jenkins-server" >> /etc/hosts
      echo "${proxmox_vm_qemu.monitoring-server.default_ipv4_address} monitoring-server" >> /etc/hosts

      echo "Hosts file updated."
    EOT
  }
}


resource "null_resource" "create_k8s_cluster" {
    depends_on = [local_file.create_ansible_inventory]
    provisioner "local-exec" {
        command = "sleep 60;ansible-playbook -i ./inventory.ini playbook-create-k8s-cluster.yml -u ${var.ci_user}"
    }
}

resource "null_resource" "create_monitoring_server" {
    depends_on = [null_resource.create_k8s_cluster]
    provisioner "local-exec" {
        command = "sleep 10;ansible-playbook -i ./inventory.ini playbook-prometheus-grafana.yml -u ${var.ci_user}"
    }
}

resource "null_resource" "create_jenkins_server" {
    depends_on = [null_resource.create_monitoring_server]
    provisioner "local-exec" {
        command = "sleep 10;ansible-playbook -i ./inventory.ini playbook-jenkins-server.yml -u ${var.ci_user}"
    }
}