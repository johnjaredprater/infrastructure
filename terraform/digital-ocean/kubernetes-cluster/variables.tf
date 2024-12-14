variable "project_id" {
  description = "Digital Ocean Project ID"
  type        = string
  default     = "aefa5c29-f8be-401c-b284-8225d3c88a91" # Find using doctl projects list
}

variable "region" {
  description = "Data Center Region"
  type        = string
  default     = "lon1"
}

