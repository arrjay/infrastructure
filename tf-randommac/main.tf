resource "random_id" "mac" {
  keepers = {
    sysmac = "${var.maddr}"
  }

  byte_length = 3
  prefix      = "${var.prefix}"
}
