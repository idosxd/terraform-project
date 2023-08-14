variable "web_password" {}

variable "db_password" {}

variable "postgresql_password" {}

variable "secret_key_py" {}

variable "my_ip" {}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "aquatrack"
}

variable "environment_name" {
  type        = string
  description = "Name of the environment"
  default     = "dev"
}

variable "location_name" {
  type        = string
  description = "Name of the location"
  default     = "westeurope"
}
