# variable "instance_name" {
#   description = "Value of the Name tag for the EC2 instance"
#   type        = string
#   default     = "ExampleAppServerInstance"
# }

variable "cidr_priv1" {
  type    = string
  default = "10.1.1.0/24"
}

variable "cidr_priv2" {
  type    = string
  default = "10.1.2.0/24"
}
variable "cidr_pub1" {
  type    = string
  default = "10.1.3.0/24"
}
variable "cidr_pub2" {
  type    = string
  default = "10.1.4.0/24"
}

variable "az_sub1" {
  type    = string
  default = "us-west-1c"
}

variable "az_sub2" {
  type    = string
  default = "us-west-1b"
}
variable "az_sub3" {
  type    = string
  default = "us-west-1c"
}
variable "az_sub4" {
  type    = string
  default = "us-west-1b"
}

variable "sg-web" {
  default = "web_sg"
}

variable "ami-west-1" {
  default = "ami-060d3509162bcc386"
}

variable "instance-type" {
  default = "t2.micro"
}

variable "key-name" {
  default = "cali"
}

