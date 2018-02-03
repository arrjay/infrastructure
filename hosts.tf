locals {
/*
  kallax-mapping = "${map("${lookup(var.kallax_hwid,"ether","")}" != "" ? "lr-kallax-sw" : "",
                          "${lookup(var.kallax_hwid,"ether","")}" != "" ?
                            "${map()}" : "${map()}")}"
}
  nickel-hw      = "${map("${lookup(var.nickel_hwid,"ether","")}" != "" ? "
  host-mac-net-mapping = "${map(
    "nickel-hw",    "${map("class","hypervisor","hwaddr","${lookup(var.nickel_hwid,"ether")}")}",
    "radon-hw",     "${map("class","hypervisor","hwaddr","${lookup(var.radon_hwid,"ether")}")}",
    "tungsten-hw",  "${map("class","hypervisor","hwaddr","${lookup(var.tungsten_hwid,"ether")}")}",
    "strontium-hw", "${map("class","hypervisor","hwaddr","${lookup(var.strontium_hwid,"ether")}")}",
    "nickel",       "${map("class","hypervisor","hwaddr",random_id.nickel_mac.hex)}",
    "radon",        "${map("class","hypervisor","hwaddr",random_id.radon_mac.hex)}",
    "tungsten",     "${map("class","hypervisor","hwaddr",random_id.tungsten_mac.hex)}",
    "strontium",    "${map("class","hypervisor","hwaddr",random_id.strontium_mac.hex)}",
  )}"

  mac-remapping = "${map(
    lookup(var.radon_hwid,"ether"),random_id.radon_mac.hex,
    lookup(var.tungsten_hwid,"ether"),random_id.tungsten_mac.hex,
    lookup(var.strontium_hwid,"ether"),random_id.strontium_mac.hex,
  )}"

*/
  host-mac-net-mapping = "module.host_struct_kallax.px_hostmap"

  mac-remapping = "${map()}"

  mac-keys = "${keys(local.mac-remapping)}"
}

module "host_struct_kallax" {
  source = "tf-hoststruct"
  host   = "kallax"
  class  = "netmgmt"
  maddr  = "${lookup(var.kallax_hwid,"ether","")}"
}

module "random_mac_nickel" {
  source = "tf-randommac"
  maddr  = "${lookup(var.nickel_hwid,"ether","")}"
  prefix = "${var.mac-prefix}"
}

module "random_mac_radon" {
  source = "tf-randommac"
  maddr  = "${lookup(var.radon_hwid,"ether","")}"
  prefix = "${var.mac-prefix}"
}

module "random_mac_tungsten" {
  source = "tf-randommac"
  maddr  = "${lookup(var.tungsten_hwid,"ether","")}"
  prefix = "${var.mac-prefix}"
}

module "random_mac_strontium" {
  source = "tf-randommac"
  maddr  = "${lookup(var.strontium_hwid,"ether","")}"
  prefix = "${var.mac-prefix}"
}

data "template_file" "macmapper_data" {
  template = "$${source}) echo $${dest} ;;"
  count    = "${length(local.mac-keys)}"

  vars {
    dest   = "${replace(lookup(local.mac-remapping,element(local.mac-keys,count.index)),"/[.:]/","")}"
    source = "${replace(element(local.mac-keys,count.index),"/[.:]/","")}"
  }
}

data "template_file" "macmapper" {
  template = "${file("${path.module}/macmapper.sh.tpl")}"

  vars {
    macdata = "${join("\n",data.template_file.macmapper_data.*.rendered)}"
  }
}

resource "local_file" "macmapper" {
  filename = "tf-output/common/intmac-remap.sh"
  content  = "${data.template_file.macmapper.rendered}"
}

data "template_file" "mac2bridge_pln_data" {
  template = "$${source} "
  count    = "${length(var.pln_maddrs)}"

  vars {
    bridge = "pln"
    source = "${replace(element(var.pln_maddrs,count.index),"/[.:]/","")}"
  }
}

data "template_file" "mac2bridge_external_data" {
  template = "$${source} "
  count    = "${length(var.external_maddrs)}"

  vars {
    bridge = "external"
    source = "${replace(element(var.external_maddrs,count.index),"/[.:]/","")}"
  }
}

data "template_file" "mac2bridge_netm_data" {
  template = "$${source} "
  count    = "${length(var.netm_maddrs)}"

  vars {
    bridge = "external"
    source = "${replace(element(var.netm_maddrs,count.index),"/[.:]/","")}"
  }
}

data "template_file" "bridger" {
  template = "pln='$${pln_macdata}'\nexternal='$${external_macdata}'\nnetm='$${netm_macdata}'\n"

  vars {
    pln_macdata      = " ${join("",data.template_file.mac2bridge_pln_data.*.rendered)}"
    external_macdata = " ${join("",data.template_file.mac2bridge_external_data.*.rendered)}"
    netm_macdata     = " ${join("",data.template_file.mac2bridge_netm_data.*.rendered)}"
  }
}

resource "local_file" "bridger" {
  filename = "tf-output/common/intmac-bridge.sh"
  content  = "${data.template_file.bridger.rendered}"
}
