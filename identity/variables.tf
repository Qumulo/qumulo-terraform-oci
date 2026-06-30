/*
 * MIT License
 *
 * Copyright (c) 2025 Qumulo
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

variable "deployment_unique_name" {
  description = "The deployment name of your qumulo cluster."
  type        = string
}

variable "tenancy_ocid" {
  description = "The tenancy OCID for your OCI tenant. Found under the tenancy page on your OCI profile."
  type        = string
}

variable "compartment_ocid" {
  description = "The ocid of the compartment in which the Qumulo cluster is created."
  type        = string
}

variable "subnet_compartment_ocid" {
  description = "The ocid of the compartment containing the subnet which the Qumulo cluster should be created within."
  type        = string
  nullable    = false
}

variable "persistent_storage_compartment_ocid" {
  description = "The compartment ID of the compartment in which the persistent storage is deployed."
  type        = string
  nullable    = false
}

variable "persistent_storage_bucket_prefix" {
  description = "The prefix of the bucket in which the persistent storage is deployed."
  type        = string
  nullable    = false
}


variable "persistent_storage_access_model" {
  description = <<EOT
Configuration settings for cluster access to the persistent object storage

Attributes:
- mode:
    One of:
      - classic (default) - creates a new user and group for object storage access in the tenancy's default IAM domain
      - explicit - uses explicit AWS access key and secret key from pre-provisioned user with full access to the persistent object storage
      - domain - creates a new user and group for object storage access in a user specified IAM domain

- explicit_customer_secret_key_access_key:
    Required when access_style = "explicit"

- explicit_customer_secret_key_secret_key:
    Required when access_style = "explicit"

- domain_idcs_endpoint:
    Required when access_style = "domain"

- domain_identity_domain_display_name:
    Required when access_style = "domain"
EOT
  type = object({
    access_style                            = optional(string, "classic")
    explicit_customer_secret_key_access_key = optional(string)
    explicit_customer_secret_key_secret_key = optional(string)
    domain_idcs_endpoint                    = optional(string)
    domain_identity_domain_display_name     = optional(string)
  })
  default = {
    access_style                            = "classic",
    explicit_customer_secret_key_access_key = null,
    explicit_customer_secret_key_secret_key = null,
    domain_idcs_endpoint                    = null,
    domain_identity_domain_display_name     = null
  }
  validation {
    condition = contains(
      ["explicit", "classic", "domain"],
      var.persistent_storage_access_model.access_style
    )
    error_message = "persistent_storage_access_model.access_style must be one of: explicit, classic, or domain."
  }
  validation {
    condition = (
      var.persistent_storage_access_model.access_style != "explicit"
      ||
      (
        try(length(trimspace(var.persistent_storage_access_model.explicit_customer_secret_key_access_key)) > 0, false)
        &&
        try(length(trimspace(var.persistent_storage_access_model.explicit_customer_secret_key_secret_key)) > 0, false)
      )
    )

    error_message = "explicit_customer_secret_key_access_key and explicit_customer_secret_key_secret_key must be provided when access_style is 'explicit'."
  }
  validation {
    condition = (
      var.persistent_storage_access_model.access_style != "domain"
      ||
      (
        try(length(trimspace(var.persistent_storage_access_model.domain_idcs_endpoint)) > 0, false)
        &&
        try(length(trimspace(var.persistent_storage_access_model.domain_identity_domain_display_name)) > 0, false)
      )
    )

    error_message = "domain_idcs_endpoint and domain_identity_domain_display_name must be provided when access_style is 'domain'."
  }

}

variable "defined_tags" {
  description = "Defined tags to apply to all resources. Should be in the format { \"namespace.key\" = \"value\" }"
  type        = map(string)
  default     = {}
}

variable "freeform_tags" {
  description = "Free-form tags to apply to all resources."
  type        = map(string)
  default     = {}
}
