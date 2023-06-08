output "mongodb_instance" {
  value =  "${google_compute_instance.mongodb.network_interface.0.access_config.0.nat_ip}"
}

output "jenkins_password_command" {
  value = "kubectl exec --namespace default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo"
}

output "register_kubectl_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.demo.name} --region us-east1 --project ${google_project.demo.project_id}"
}

output "mongodb_instance_connect_command" {
  value = "gcloud compute ssh --zone us-east1-c mongodb --project ${google_project.demo.id}"
}
