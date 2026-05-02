variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR principal para la VPC"
  type        = string
}
variable "public_subnets" {
  description = "CIDRs para subredes publicas"
  type        = list(string)
}

variable "private_app_subnets" {
  description = "CIDRs para subredes de aplicacion"
  type        = list(string)
}

variable "private_db_subnets" {
  description = "CIDRs para subredes de base de datos"
  type        = list(string)
}

variable "azs" {
  description = "Zonas de disponibilidad"
  type        = list(string)
}