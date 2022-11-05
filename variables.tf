variable "env_name" {
  description = "String prefix for names of created resources."
  type        = string
  default     = "sample-gcp"
}

variable "mgmt_cidrs" {
  description = "List of CIDR prefixes to allow in created security groups."
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Map of tags added to created resources."
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "sample-gcp"
    Owner       = "Your-Name-SE"
  }
}

variable "region" {
  description = "GCP region to create resources in."
  type        = string
  default     = "us-east1"
}

# Update with the oldest available image, currently 1804.  Find with:
# gcloud compute images list --filter="family~ubuntu-1804-lts" --uri | grep -i arm | sed 's/https:\/\/www.googleapis.com\/compute\/v1//g'
variable "ubuntu_image_id" {
  description = "GCP Image ID for Ubuntu 18.04 LTS.  Used to create MongoDB instance."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20221018"
}

variable "gcp_service_list" {
  description = "List of GCP APIs to enable"
  type        = list
  default     = [
  "compute.googleapis.com",           # Compute Engine API
]
}

variable "billing_account" {
  description = "Billing Account."
  type        = string
}

variable "budget_name" {
  description = "Name of created budget."
  type        = string
  default     = "Monthly Budget"
}

variable "budget_amount" {
  description = "Amount to monitor in created budget."
  type        = string
  default     = "50"
}

variable "budget_currency" {
  description = "Currency for created budget."
  type        = string
  default     = "USD"
}

variable "budget_time_unit" {
  description = "Time unit for created budget."
  type        = string
  default     = "MONTH"
}

variable "budget_email" {
  description = "Email address to send budget alerts to."
  type        = string
  default     = "your@email.com"
}
