variable "tag_prefix" {
  type    = string
  default = "flamarion-k8s"
}

variable "dns_record_name" {
  type    = string
  default = "flamarion-k8s"
}

variable "http_port" {
  type    = number
  default = 80
}

variable "https_port" {
  type    = number
  default = 443
}

variable "public_networks" {
  type = list(string)
  default = [
    "10.1.0.0/24",
    "10.2.0.0/24",
    "10.3.0.0/24"
  ]
}

# variable "private_networks" {
#   type = list(string)
#   default = [
#     "10.11.0.0/24",
#     "10.12.0.0/24",
#     "10.13.0.0/24"
#   ]
# }

variable "az" {
  type = list(string)
  default = [
    "eu-central-1a",
    "eu-central-1b",
    "eu-central-1c"
  ]
}