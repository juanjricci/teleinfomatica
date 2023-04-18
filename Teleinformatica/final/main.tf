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

# creo la red

resource "openstack_networking_network_v2" "jr-net" {
  name           = "jr-net"
  admin_state_up = "true"
}

# creo la subred
resource "openstack_networking_subnet_v2" "jr-subnet" {
  name       = "jr-subnet"
  network_id = "${openstack_networking_network_v2.jr-net.id}"
  cidr       = "172.19.0.0/24"
  ip_version = 4
}

# creo un router
resource "openstack_networking_router_v2" "jr-router" {
  name                = "jr-router"
  admin_state_up      = true
  external_network_id = "4cd100c4-1652-47b1-b63b-a69f96a06355"
}

# asigno una interfaz al router
resource "openstack_networking_router_interface_v2" "jr-intf" {
  router_id = "${openstack_networking_router_v2.jr-router.id}"
  subnet_id = "${openstack_networking_subnet_v2.jr-subnet.id}"
}

# security groups
resource "openstack_compute_secgroup_v2" "sg-jumphost" {
    name = "sg-jumphost"
    description = "Jump Host security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }

    rule {
        from_port = -1
        to_port = -1
        ip_protocol = "icmp"
        cidr = "0.0.0.0/0"
    }

}

resource "openstack_compute_secgroup_v2" "sg-fe" {
    name = "sg-fe"
    description = "Front End security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-jumphost.id}"
    }

    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }

}

resource "openstack_compute_secgroup_v2" "sg-ws" {
    name = "sg-ws"
    description = "Front End security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-jumphost.id}"
    }

    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-fe.id}"
    }

}

# creo las instancias
resource "openstack_compute_instance_v2" "jr-jumphost" {
  name = "jr-jumphost"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-jumphost.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-fe" {
  name = "jr-fe"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-fe.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-ws-01" {
  name = "jr-ws-01"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-ws.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-ws-02" {
  name = "jr-ws-02"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-ws.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-ws-03" {
  name = "jr-ws-03"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-ws.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

# creo la IP flotante 1
resource "openstack_compute_floatingip_v2" "jr-floatip" {
    pool = "ext_net"  
}

# asocio IP flotante 1
resource "openstack_compute_floatingip_associate_v2" "jr-floatip" {
  floating_ip = "${openstack_compute_floatingip_v2.jr-floatip.address}"
  instance_id = "${openstack_compute_instance_v2.jr-jumphost.id}"
}

# creo IP flotante 2
resource "openstack_compute_floatingip_v2" "jr-floatip-2" {
    pool = "ext_net"  
}

# asocio IP flotante 2
resource "openstack_compute_floatingip_associate_v2" "jr-floatip-2" {
  floating_ip = "${openstack_compute_floatingip_v2.jr-floatip-2.address}"
  instance_id = "${openstack_compute_instance_v2.jr-fe.id}"
}