variable "environments" {
  type = map(object({
    location         = string
    vm_admin_password = string
  }))
}

variable "location" {
  type    = string
  default = "East US"
}
