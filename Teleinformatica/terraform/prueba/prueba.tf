terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.48.0"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  user_name   = "j.ricci__alumno.um.edu.ar"
  tenant_name = "j.ricci__alumno.um.edu.ar_project"
  password    = "0ayydskpgBwdtsPkuswNe9lzqzpk3F8L"
  auth_url    = "http://keystone.openstack.svc.metal.kube.um.edu.ar/v3"
  region      = "RegionOne"
}

# creamos la red (switch)
resource "openstack_networking_network_v2" "jr-net" {
  name           = "jr-net"
  admin_state_up = "true"
}