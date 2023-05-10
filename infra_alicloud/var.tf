variable "vpc_cidr_block" {
  type = string
}
variable "vpc_tags" {
  type = map(string)
}

variable "public_subnet_cidr" {
  type = list(string)
}
variable "private_subnet" {
  type = string
}

variable "min_size" {
  type = string
}
variable "max_size" {
  type = string
}
variable "min_elb" {
  type = string
}

