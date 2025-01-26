provider "aws" {
  region = var.aws_region
}

locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  count             = length(var.public_subnets_cidr)
  cidr_block        = element(var.public_subnets_cidr, count.index)
  availability_zone = element(local.availability_zones, count.index)

  tags = {
    Name        = "${var.environment}-${element(local.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  count             = length(var.private_subnets_cidr)
  cidr_block        = element(var.private_subnets_cidr, count.index)
  availability_zone = element(local.availability_zones, count.index)

  tags = {
    Name        = "${var.environment}-${element(local.availability_zones, count.index)}-private-subnet"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "trusted_subnet" {
  vpc_id            = aws_vpc.vpc.id
  count             = length(var.trusted_subnets_cidr)
  cidr_block        = element(var.trusted_subnets_cidr, count.index)
  availability_zone = element(local.availability_zones, count.index)

  tags = {
    Name        = "${var.environment}-${element(local.availability_zones, count.index)}-trusted-subnet"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "mgmt_subnet" {
  vpc_id            = aws_vpc.vpc.id
  count             = length(var.mgmt_subnets_cidr)
  cidr_block        = element(var.mgmt_subnets_cidr, count.index)
  availability_zone = element(local.availability_zones, count.index)

  tags = {
    Name        = "${var.environment}-${element(local.availability_zones, count.index)}-mgmt-subnet"
    Environment = "${var.environment}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)

  tags = {
    Name        = "${var.environment}-nat-gateway"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table" "mgmt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-mgmt-route-table"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table" "trusted" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-trusted-route-table"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "mgmt" {
  route_table_id         = aws_route_table.mgmt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "trusted" {
  route_table_id         = aws_route_table.trusted.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "mgmt" {
  count          = length(var.mgmt_subnets_cidr)
  subnet_id      = element(aws_subnet.mgmt_subnet.*.id, count.index)
  route_table_id = aws_route_table.mgmt.id
}

resource "aws_route_table_association" "trusted" {
  count          = length(var.trusted_subnets_cidr)
  subnet_id      = element(aws_subnet.trusted_subnet.*.id, count.index)
  route_table_id = aws_route_table.trusted.id
}
