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

# creamos la subred v4

resource "openstack_networking_subnet_v2" "jr-subnet4" {
  name       = "jr-subnet4"
  network_id = "${openstack_networking_network_v2.jr-net.id}"
  cidr       = "172.19.0.0/24"
  ip_version = 4
}

# creamos la subred v6

# resource "openstack_networking_subnet_v2" "jr-subnet6" {
#   name       = "jr-subnet6"
#   network_id = "${openstack_networking_network_v2.jr-net.id}"
#   cidr       = "fe80:de40:fe21::/48"
#   ip_version = 6
# }

# creamos un router
resource "openstack_networking_router_v2" "jr-router" {
  name                = "jr-router"
  admin_state_up      = true
  external_network_id = "4cd100c4-1652-47b1-b63b-a69f96a06355"
}

# asignamos una interfaz v4 al router
resource "openstack_networking_router_interface_v2" "jr-intf4" {
  router_id = "${openstack_networking_router_v2.jr-router.id}"
  subnet_id = "${openstack_networking_subnet_v2.jr-subnet4.id}"
}

# # asignamos una interfaz v6 al router
# resource "openstack_networking_router_interface_v2" "jr-intf6" {
#   router_id = "${openstack_networking_router_v2.jr-router.id}"
#   subnet_id = "${openstack_networking_subnet_v2.jr-subnet6.id}"
# }

# security groups
resource "openstack_compute_secgroup_v2" "sg-bastion" {
    name = "sg-bastion"
    description = "Bastion security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        cidr = "::/0"
    }

}

resource "openstack_compute_secgroup_v2" "sg-lb" {
    name = "sg-lb"
    description = "Load Balancer security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-bastion.id}"
    }

    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }

    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        cidr = "::/0"
    }
}

resource "openstack_networking_secgroup_rule_v2" "sg-lb_rule_1" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = "${openstack_compute_secgroup_v2.sg-bastion.id}"
  security_group_id = "${openstack_compute_secgroup_v2.sg-lb.id}"
}

resource "openstack_compute_secgroup_v2" "sg-webapp-01" {
    name = "sg-webapp-01"
    description = "Webapp-01 security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-bastion.id}"
    }
    
    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-lb.id}"
    }

    rule {
        from_port = -1
        to_port = -1
        ip_protocol = "icmp"
        cidr = "0.0.0.0/0"
    }

    rule {
        from_port = -1
        to_port = -1
        ip_protocol = "icmp"
        cidr = "::/0"
    }
}

resource "openstack_networking_secgroup_rule_v2" "sg-wa_rule_1" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = "${openstack_compute_secgroup_v2.sg-bastion.id}"
  security_group_id = "${openstack_compute_secgroup_v2.sg-webapp-01.id}"
}

resource "openstack_networking_secgroup_rule_v2" "sg-wa_rule_2" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = "${openstack_compute_secgroup_v2.sg-lb.id}"
  security_group_id = "${openstack_compute_secgroup_v2.sg-webapp-01.id}"
}

resource "openstack_compute_secgroup_v2" "sg-db" {
    name = "sg-db"
    description = "Database security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-bastion.id}"
    }
    
    rule {
        from_port = 3306
        to_port = 3306
        ip_protocol = "tcp"
        from_group_id = "${openstack_compute_secgroup_v2.sg-webapp-01.id}"
    }
}

resource "openstack_networking_secgroup_rule_v2" "sg-db_rule_1" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = "${openstack_compute_secgroup_v2.sg-bastion.id}"
  security_group_id = "${openstack_compute_secgroup_v2.sg-db.id}"
}

resource "openstack_networking_secgroup_rule_v2" "sg-db_rule_2" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_group_id   = "${openstack_compute_secgroup_v2.sg-webapp-01.id}"
  security_group_id = "${openstack_compute_secgroup_v2.sg-db.id}"
}
# instancias
resource "openstack_compute_instance_v2" "jr-bastion" {
  name = "jr-bastion"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-bastion.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-lb" {
  name = "jr-lb"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-lb.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-webapp-01" {
  name = "jr-webapp-01"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-webapp-01.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

resource "openstack_compute_instance_v2" "jr-db" {
  name = "jr-db"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-db.name}"]

  network {
    name = "${openstack_networking_network_v2.jr-net.name}"
  }
}

# crear IP flotante 1
resource "openstack_compute_floatingip_v2" "jr-floatip" {
    pool = "ext_net"  
}

# asociar IP flotante 1
resource "openstack_compute_floatingip_associate_v2" "jr-floatip" {
  floating_ip = "${openstack_compute_floatingip_v2.jr-floatip.address}"
  instance_id = "${openstack_compute_instance_v2.jr-lb.id}"
}

# crear IP flotante 2
resource "openstack_compute_floatingip_v2" "jr-floatip-2" {
    pool = "ext_net"  
}

# asociar IP flotante 2
resource "openstack_compute_floatingip_associate_v2" "jr-floatip-2" {
  floating_ip = "${openstack_compute_floatingip_v2.jr-floatip-2.address}"
  instance_id = "${openstack_compute_instance_v2.jr-bastion.id}"
}