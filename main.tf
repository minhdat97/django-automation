// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
 name         = "vm-${random_id.instance_id.hex}"
 machine_type = "g1-small"
 zone         = "us-central1-a"

 boot_disk {
   initialize_params {
     image = "ubuntu-os-cloud/ubuntu-1804-lts"
   }
 }
 tags = ["ubuntu-firewall-ssh", "ubuntu-firewall-http", "ubuntu-firewall-https", "ubuntu-firewall-icmp"]

// Make sure flask is installed on all new instances for later step

 provisioner "remote-exec" {
  inline = ["while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done; sudo rm /var/lib/apt/lists/* ; sudo apt-get update ; sudo apt-get install -y python python-pip ; sudo apt-get install -y python python3-pip"] 

  connection {
    host        = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
    type        = "ssh"
    user        = "ubuntu"
    private_key = "${file(var.private_key)}"
  }
 }

 provisioner "local-exec" {
       command = <<EOT
   sleep 30;
	 >inventory.ini;
	 echo "[servers]" | tee -a inventory.ini;
	 echo "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip} ansible_user=${var.ansible_user} ansible_ssh_private_key_file=${var.private_key}" | tee -a inventory.ini;
   export ANSIBLE_HOST_KEY_CHECKING=False;
	 ansible-playbook -u ${var.ansible_user} --private-key ${var.private_key} -i inventory.ini provision.yml
   EOT
 }
 
 metadata = {
   ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
 }

 network_interface {
   network = "default"

   access_config {
     // Include this section to give the VM an external ip address
   }
 }
}

resource "google_compute_network" "ubuntu_network" {
  name                    = "ubuntu-network"
}

resource "google_compute_firewall" "ssh" {
  name    = "ubuntu-firewall-ssh"
  network = "${google_compute_network.ubuntu_network.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["ubuntu-firewall-ssh"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "http" {
  name    = "ubuntu-firewall-http"
  network = "${google_compute_network.ubuntu_network.name}"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags   = ["ubuntu-firewall-http"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "https" {
  name    = "ubuntu-firewall-https"
  network = "${google_compute_network.ubuntu_network.name}"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags   = ["ubuntu-firewall-https"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "icmp" {
  name    = "ubuntu-firewall-icmp"
  network = "${google_compute_network.ubuntu_network.name}"

  allow {
    protocol = "icmp"
  }

  target_tags   = ["ubuntu-firewall-icmp"]
  source_ranges = ["0.0.0.0/0"]
}


