locals {
  mac_entr  = "${var.maddr != "" ? "${map()}" : "${map()}"}"
  rmac_entr = "${map()}"
}
