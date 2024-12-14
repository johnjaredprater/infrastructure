variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "firebase-credentials-path" {
  description = "path to firebase credentials"
  type        = string
  default     = "~/gym-tracking-firebase-key.json"
}