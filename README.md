# sample-aws

Terraform implementation of a vulnerable infrastructure in AWS.

Uses community modules from the [terraform-provider-google](https://github.com/hashicorp/terraform-provider-google) project.

## Usage

Install the google cloud command line tools ([guide here](https://cloud.google.com/sdk/docs/install)).

Create a project in Google Cloud

Other variables found in `variables.tf` can be customized in `terraform.tfvars` as well.

Run standard Terraform setup:

```
terraform init
terraform plan
terraform apply -auto-approve
```

Terraform will build the following:
- VPC
- Security Groups (accessible from `0.0.0.0/0`)
- MongoDB instance (over-permissive IAM roles TBD)
- S3 Bucket (globally accessible)
- GKE autopilot cluster running [Jenkins Helm chart](https://github.com/jenkinsci/helm-charts)

This can take 10-20 minutes.  Once done, you can log in to the MongoDB instance using the gcloud command:

`gcloud compute ssh --zone "us-east1-c" "mongodb"  --project "$PROJECT_ID"`

For the Kubernetes cluster and the Jenkins deployment, first pull the kubeconfig from the created cluster:

`gcloud container clusters get-credentials $CLUSTER_NAME --region us-east1 --project $PROJECT_ID`

Verify connectivity using `kubectl get nodes`:
```
NAME                                                  STATUS   ROLES    AGE     VERSION
gk3-sample-gcp-gke-8f473-default-pool-2ff02bb9-1v40   Ready    <none>   6m50s   v1.23.8-gke.1900
gk3-sample-gcp-gke-8f473-default-pool-fa31c74c-2mks   Ready    <none>   6m50s   v1.23.8-gke.1900
gk3-sample-gcp-gke-8f473-nap-1xd9lkku-310f9805-z9hg   Ready    <none>   4m38s   v1.23.8-gke.1900
```

Get the admin password of Jenkins with:
```
kubectl exec --namespace default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

Get the IP address of the created load balancer with `kubectl get svc --namespace default jenkins`

```
NAME      TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)          AGE
jenkins   LoadBalancer   10.32.130.166   35.227.102.232   8080:32722/TCP   6m18s
```

The Jenkins UI will be at http://<EXTERNAL-IP>:8080.  You can login with `admin` and the password you retrieved above.
