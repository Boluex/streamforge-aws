output "load_balancer_dns" { value = aws_lb.main.dns_name }
output "cluster_name" { value = aws_ecs_cluster.main.name }
output "service_name" { value = aws_ecs_service.main.name }
output "image_repositories" { value = { for name, repo in aws_ecr_repository.images : name => repo.repository_url } }
output "media_file_system_id" { value = aws_efs_file_system.main.id }
