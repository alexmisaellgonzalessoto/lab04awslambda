variable "region_aws" {
  description = "Región de AWS indicada en la arquitectura."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "perfil_aws" {
  description = "Nombre del perfil de AWS configurado fuera del repositorio."
  type        = string
  default     = "lab04awslambda"
  nullable    = false

  validation {
    condition     = length(trimspace(var.perfil_aws)) > 0
    error_message = "El nombre del perfil de AWS no puede estar vacío."
  }
}

variable "entorno" {
  description = "Entorno que se desplegará: dev, qa o prod."
  type        = string
  default     = "dev"
  nullable    = false

  validation {
    condition     = contains(["dev", "qa", "prod"], var.entorno)
    error_message = "El entorno debe ser dev, qa o prod."
  }
}

variable "nombre_proyecto" {
  description = "Nombre utilizado para identificar los recursos del proyecto."
  type        = string
  default     = "lab04awslambda"
  nullable    = false
}
