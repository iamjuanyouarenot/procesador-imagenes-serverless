# 1. La VPC Principal (DNS activado es obligatorio para los VPC Endpoints)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-serverless-${var.environment}"
  }
}

# 2. Subredes Públicas (10.0.1.0/24 y 10.0.2.0/24 según diagrama)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${var.environment}-${var.azs[count.index]}"
  }
}

# 3. Subredes Privadas (10.0.11.0/24 y 10.0.12.0/24 según diagrama)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "private-subnet-${var.environment}-${var.azs[count.index]}"
  }
}

# 4. Internet Gateway y NAT Gateways (Alta Disponibilidad)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${var.environment}" }
}

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
  tags   = { Name = "eip-nat-${var.environment}-${count.index + 1}" }
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "nat-${var.environment}-${var.azs[count.index]}" }
}

# 5. Tablas de Enrutamiento (Pública y 2 Privadas)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rt-public-${var.environment}" }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = { Name = "rt-private-${var.environment}-${var.azs[count.index]}" }
}

# Asociaciones de Subredes
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ==========================================
# VPC ENDPOINTS (El núcleo de la seguridad Serverless)
# ==========================================

# 6. Gateway Endpoint para S3 (Gratis, no usa IPs)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private[0].id, aws_route_table.private[1].id]
  
  tags = { Name = "vpce-s3-${var.environment}" }
}

# 7. Security Group para el Endpoint de SQS
resource "aws_security_group" "vpce_sqs_sg" {
  name        = "sg-vpce-sqs-${var.environment}"
  description = "Permitir HTTPS interno hacia SQS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Solo permite tráfico de nuestra propia VPC
  }
}

# 8. Interface Endpoint para SQS
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  security_group_ids  = [aws_security_group.vpce_sqs_sg.id]
  private_dns_enabled = true

  tags = { Name = "vpce-sqs-${var.environment}" }
}