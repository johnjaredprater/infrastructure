variable "region" {
  description = "Data Center Region"
  type        = string
  default     = "lon1"
}


variable "firebase-credentials-path" {
  description = "Path to firebase credentials"
  type        = string
  default     = "~/gym-tracking-firebase-key.json"
}