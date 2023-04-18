terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.48.0"
    }
  }
}

# creamos la red (switch)
resource "openstack_networking_network_v2" "jr-net" {
  name           = "jr-net"
  admin_state_up = "true"
}

# creamos la subred
resource "openstack_networking_subnet_v2" "jr-subnet" {
  name       = "jr-subnet"
  network_id = "${openstack_networking_network_v2.jr-net.id}"
  cidr       = "172.19.0.0/24"
  ip_version = 4
}

# creamos un router
resource "openstack_networking_router_v2" "jr-router" {
  name                = "jr-router"
  admin_state_up      = true
  external_network_id = "4cd100c4-1652-47b1-b63b-a69f96a06355"
}

# asignamos una interfaz al router
resource "openstack_networking_router_interface_v2" "jr-intf" {
  router_id = "${openstack_networking_router_v2.jr-router.id}"
  subnet_id = "${openstack_networking_subnet_v2.jr-subnet.id}"
}

# crear los security groups
resource "openstack_compute_secgroup_v2" "sg-bastion" {
  name = "sg-bastion"
  description = "Bastion security group"

  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  

}

resource "openstack_compute_secgroup_v2" "sg-lb" {
    name = "sg-lb"
    description = "Load Balancer security group"

    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
        #from_group_id = "${openstack_compute_secgroup_v2.sg-bastion.id}"
    }
    
    rule {
        from_port = 80
        to_port = 80
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
  
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

}

resource "openstack_compute_secgroup_v2" "sg-webapp-02" {
  name = "sg-webapp-02"
  description = "Webapp-02 security group"

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

  rule {
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    from_group_id = "${openstack_compute_secgroup_v2.sg-webapp-02.id}"
  }
}

# crear las instancias
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

resource "openstack_compute_instance_v2" "jr-webapp-02" {
  name = "jr-webapp-02"
  image_name = "ubuntu_minimal_1804"
  flavor_name = "m1.small"
  key_pair = "jr-key"
  security_groups = ["${openstack_compute_secgroup_v2.sg-webapp-02.name}"]

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

# crear IP flotante
resource "openstack_compute_floatingip_v2" "jr-floatip" {
    pool = "ext_net"  
}

# asociar IP flotante
resource "openstack_compute_floatingip_associate_v2" "jr-floatip" {
  floating_ip = "${openstack_compute_floatingip_v2.jr-floatip.address}"
  instance_id = "${openstack_compute_instance_v2.jr-lb.id}"
}

# # crear IP flotante
# resource "openstack_compute_floatingip_v2" "jr-floatip-2" {
#     pool = "ext_net"  
# }

# # asociar IP flotante
# resource "openstack_compute_floatingip_associate_v2" "jr-floatip-2" {
#   floating_ip = "${openstack_compute_floatingip_v2.jr-floatip-2.address}"
#   instance_id = "${openstack_compute_instance_v2.jr-lb.id}"
# }


