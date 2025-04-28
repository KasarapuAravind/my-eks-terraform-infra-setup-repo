output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  value       = [for subnet in aws_subnet.private : subnet.cidr_block]
}

