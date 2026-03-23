variable "cluster_name" {
  description = "EKS cluster name" 
  type        = string
}

variable "cluster_version" {
  description = "k8s version"
  type        = string
}

variable "owner" {
  description = "Owner tag for all resources"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet_ids (networking module)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet_ids (networking module)"
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDRs"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "Control plane logs for CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "instance_types" {
  description = "Tipos de instancia para los worker nodes."
  type        = list(string)
  default     = ["t3.medium"]  # 2 vCPU, 4 GB 
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size" {
  description = "EBS disk size for each node"
  type        = number
  default     = 20
}

variable "desired_nodes" {
  description = "desired nodes"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "min nodes"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Max nodes"
  type        = number
  default     = 4
}

variable "node_labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}