resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true
    instance_tenancy = "default"
    tags = merge(var.tags, {
        Name = "${var.cluster_name}-vpc"
    })
}

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags,{
        Name = "${var.cluster_name}-igw"
    })
}

resource "aws_eip" "nat" {
    domain = "vpc"
    tags = merge(var.tags, {
        Name = "${var.cluster_name}-nat-eip"
    })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.this]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat"
  })
}

resource "aws_subnet" "public" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.public_subnet_cidrs[count.index]
    availability_zone = var.azs[count.index]
    map_public_ip_on_launch = true
    tags = merge(var.tags, {
        Name = "${var.cluster_name}-public-${count.index}"
        "kubernetes.io/role/elb" = "1"
    })
}

resource "aws_subnet" "private" {
    count = length(var.private_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.private_subnet_cidrs[count.index]
    availability_zone = var.azs[count.index]
    tags = merge(var.tags, {
        Name = "${var.cluster_name}-private-${count.index}"
        "kubernetes.io/role/internal-elb" = "1"
    })
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {
        Name = "${var.cluster_name}-public-rt"
    })  
}

resource "aws_route" "public_internet_access" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id  
}

resource "aws_route_table_association" "public" {
    count = length(aws_subnet.public)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
  
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {
        Name = "${var.cluster_name}-private-rt"
    }) 
}

resource "aws_route" "private_nat_gateway" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
    count = length(aws_subnet.private)
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private.id  
}