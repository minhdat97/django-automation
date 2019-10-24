# Specify the provider (GCP, AWS, Azure)
provider "google" {
credentials = "${file("./creds/web-terraform-ansible-495b7770e1e2.json")}"
project = "web-terraform-ansible"
region = "us-central1"
}
