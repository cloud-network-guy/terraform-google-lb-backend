variable "create" {
  type    = bool
  default = null
}
variable "project_id" {
  type = string
}
variable "host_project_id" {
  type    = string
  default = null
}
variable "type" {
  type    = string
  default = null
}
variable "region" {
  type    = string
  default = null
}
variable "network" {
  type    = string
  default = null
}
variable "subnet" {
  type    = string
  default = null
}
variable "name_prefix" {
  type    = string
  default = null
}
variable "name" {
  type    = string
  default = null
}
variable "description" {
  type    = string
  default = null
}
variable "classic" {
  type    = bool
  default = null
}
variable "port" {
  type    = number
  default = null
}
variable "protocol" {
  type    = string
  default = null
}
variable "logging" {
  type    = bool
  default = null
}
variable "timeout" {
  type    = number
  default = null
}
variable "health_check" {
  type    = string
  default = null
}
variable "health_checks" {
  type    = list(string)
  default = null
}
variable "security_policy" {
  type    = string
  default = null
}
variable "session_affinity" {
  type    = string
  default = null
}
variable "bucket" {
  type    = string
  default = null
}
variable "groups" {
  type    = list(string)
  default = null
}
variable "locality_lb_policy" {
  type    = string
  default = null
}
variable "capacity_scaler" {
  type    = number
  default = null
}
variable "max_utilization" {
  type    = number
  default = null
}
variable "max_rate_per_instance" {
  type    = number
  default = null
}
variable "max_connections" {
  type    = number
  default = null
}
variable "connection_draining_timeout" {
  type    = number
  default = null
}
variable "iap" {
  type = object({
    application_title = optional(string)
    support_email     = optional(string)
    members           = optional(list(string))
  })
  default = null
}
variable "instance_groups" {
  type = list(object({
    id         = optional(string)
    project_id = optional(string)
    zone       = optional(string)
    name       = optional(string)
  }))
  default = null
}
variable "negs" {
  type = list(object({
    id                = optional(string)
    project_id        = optional(string)
    name              = optional(string)
    type              = optional(string)
    region            = optional(string)
    zone              = optional(string)
    instance          = optional(string)
    network           = optional(string)
    subnet            = optional(string)
    fqdn              = optional(string)
    ip_address        = optional(string)
    protocol          = optional(string)
    port              = optional(number)
    psc_target        = optional(string)
    cloud_run_service = optional(string) # Cloud run service name
  }))
  default = []
}
variable "cdn" {
  type = object({
    cache_mode = optional(string)
  })
  default = null
}
