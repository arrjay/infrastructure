# sv1 is split into three nodes...
variable "nodes" {
  default = ["node-1", "node-2", "node-1a"]
}

module "node-1" {
  source          = "./node"
  series          = "1"
  supernet        = "${local.block-node-1}"
  domainname      = "${var.domainname}"
  user-vlan       = "10"
  restricted-vlan = "20"
  guest-vlan      = "30"
  wext-vlan       = "40"
  iot-vlan        = "50"
}

module "node-1a" {
  source          = "./node"
  series          = "1a"
  supernet        = "${local.block-node-1a}"
  domainname      = "${var.domainname}"
  user-vlan       = "12"
  restricted-vlan = "22"
  guest-vlan      = "32"
  wext-vlan       = "42"
  iot-vlan        = "52"
}

module "node-2" {
  source          = "./node"
  series          = "2"
  supernet        = "${local.block-node-2}"
  domainname      = "${var.domainname}"
  user-vlan       = "11"
  restricted-vlan = "21"
  guest-vlan      = "31"
  wext-vlan       = "41"
  iot-vlan        = "51"
}

locals {
  host-map = "${merge(var.host-map, module.node-1.host-map, module.node-2.host-map, module.node-1a.host-map)}"

  # dhcp-1 also gets wifiext, powerline networks
  #  host-map     = "${map()}"
  dhcp-1-range = "${merge(module.node-1.networks, local.wext-1-range, local.pln-1-range)}"

  vlan-map  = "${merge(module.node-1.vlans, module.node-2.vlans, module.node-1a.vlans)}"
  vlan-keys = "${keys(local.vlan-map)}"
}

# capture generated macs for bootstrap-scripts
data "template_file" "ifw_macs" {
  template = "sv1) echo $${sv1} ;;\nsv1a) $${sv1a} ;;\nsv2) $${sv2} ;;\n"

  vars {
    sv1  = "${lookup(local.host-map["ifw.sv1.bbxn.us"],"hwaddr")}"
    sv1a = "${lookup(local.host-map["ifw.sv1a.bbxn.us"],"hwaddr")}"
    sv2  = "${lookup(local.host-map["ifw.sv2.bbxn.us"],"hwaddr")}"
  }
}

data "template_file" "ifwmapper" {
  template = "${file("${path.module}/macmapper.sh.tpl")}"

  vars {
    macdata = "${data.template_file.ifw_macs.rendered}"
  }
}

resource "local_file" "ifw_mapping" {
  filename = "tf-output/common/ifw-mac-addrs.sh"
  content  = "${data.template_file.ifwmapper.rendered}"
}

# dhcp(/tftp) servers
module "dhcp-1" {
  source          = "./dhcp-server"
  addr            = "${local.tftp-1-subrange}"
  fqdn            = "netmgmt.sv1.${var.domainname}"
  ranges          = "${local.dhcp-1-range}"
  restricted_nets = "${module.node-1.restricted-nets}"
  host-map        = "${local.host-map}"
}

module "dhcp-2" {
  source          = "./dhcp-server"
  addr            = "${local.tftp-2-subrange}"
  fqdn            = "netmgmt.sv2.${var.domainname}"
  ranges          = "${module.node-2.networks}"
  restricted_nets = "${module.node-2.restricted-nets}"
  host-map        = "${local.host-map}"
}

module "dhcp-1a" {
  source          = "./dhcp-server"
  addr            = "${local.tftp-1a-subrange}"
  fqdn            = "netmgmt.sv1a.${var.domainname}"
  ranges          = "${module.node-1a.networks}"
  restricted_nets = "${module.node-1a.restricted-nets}"
  host-map        = "${local.host-map}"
}
