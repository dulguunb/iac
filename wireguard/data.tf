data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = ["Ubuntu 25.04 x64"]
  }
}

data "vultr_plan" "cheap" {
  filter {
    name   = "id"
    values = ["vc2-1c-2gb"]
  }
}

data "vultr_region" "frankfurt" {
  filter {
    name   = "id"
    values = ["fra"]
  }
}