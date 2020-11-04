# output "vpc_id" {
#   value = module.k8s_vpc.vpc_id
# }

output "az" {
  value = module.k8s_vpc.az
}

output "public_subnets" {
  value = module.k8s_vpc.public_subnets
}

output "public_subnets_id" {
  value = module.k8s_vpc.public_subnets_id
}

output "master" {
  value = [
    aws_instance.k8s_master.*.public_dns,
    aws_instance.k8s_master.*.public_ip,
    aws_instance.k8s_master.*.private_dns,
    aws_instance.k8s_master.*.private_ip,
  ]
}

output "worker" {
  value = [
    aws_instance.k8s_worker.*.public_dns,
    aws_instance.k8s_worker.*.public_ip,
    aws_instance.k8s_worker.*.private_dns,
    aws_instance.k8s_worker.*.private_ip,
  ]
}

output "api_dns" {
  value = aws_lb.k8s_lb.dns_name
}
