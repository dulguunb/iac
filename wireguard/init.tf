terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.13.0"
    }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

resource "vultr_ssh_key" "example" {
  name    = "my-ssh-key"
  ssh_key = var.ssh_public_key
}

resource "vultr_instance" "my_cheap_instance" {
  region  = "fra"
  plan    = "vc2-1c-1gb"
  os_id   = data.vultr_os.ubuntu.id
  backups = "disabled"
  enable_ipv6 = true
  user_data = <<-EOF
    #cloud-config
    runcmd:
      - apt install wireguard
      - apt install wireguard-tools
      - echo net.ipv4.ip_forward=1 > /etc/sysctl.conf
      - echo net.ipv6.conf.all.forwarding=1 >> /etc/sysctl.conf
      - sudo sysctl -p
      - sudo ufw allow 51820/udp
      - sudo ufw disable
      - sudo ufw enable
  EOF
  ssh_key_ids = [vultr_ssh_key.example.id]
}

output "vpn_ip" {
  value = vultr_instance.my_cheap_instance.main_ip
}
