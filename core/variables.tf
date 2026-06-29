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

variable "persistent_storage" {
  description = "The output of the persistent storage module."
  type = object({
    oci_objectstorage_namespace = string
    bucket = list(object({
      name = string
    }))
    bucket_region       = string
    bucket_prefix       = string
    object_storage_uris = list(string)
    compartment_ocid    = string
    deployment_id       = string
  })
  nullable = true
  default  = null
}

variable "node_ssh_public_key_paths" {
  description = "A list of the local paths to files containing the public keys which should be authorized to ssh into the Qumulo nodes."
  type        = list(string)
  nullable    = false
}

variable "node_ssh_public_key_strings" {
  description = "A list of the public keys which should be authorized to ssh into the Qumulo nodes."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "tenancy_ocid" {
  description = "The tenancy OCID for your OCI tenant. Found under the tenancy page on your OCI profile."
  type        = string
  nullable    = false
  validation {
    condition     = substr(var.tenancy_ocid, 0, 18) == "ocid1.tenancy.oc1."
    error_message = "The tenancy ocid should start with ocid1.tenancy.oc1."
  }
}

variable "compartment_ocid" {
  description = "The compartment into which you want your Qumulo cluster deployed."
  type        = string
  nullable    = false
  validation {
    condition     = var.compartment_ocid == var.persistent_storage.compartment_ocid
    error_message = "The compartment ocid should match the compartment ocid of the persistent storage"
  }
}

variable "subnet_ocid" {
  description = "The ocid of the subnet which the Qumulo cluster should be created within."
  type        = string
  nullable    = false
  validation {
    condition     = substr(var.subnet_ocid, 0, 17) == "ocid1.subnet.oc1."
    error_message = "The subnet ocid should start with ocid1.subnet.oc1."
  }
}

variable "q_cluster_name" {
  description = "The name of your qumulo cluster."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9\\-]{0,13}[a-zA-Z0-9]$", var.q_cluster_name))
    error_message = "The cluster name must be an alphanumeric string between 2 and 15 characters. Dash (-) is allowed if not the first or last character."
  }
}

variable "q_cluster_soft_capacity_limit" {
  description = "The maximum soft capacity of your qumulo cluster, in TB."
  type        = number
  default     = 500
  validation {
    condition     = var.q_cluster_soft_capacity_limit >= 100
    error_message = "q_cluster_soft_capacity_limit must be at least 100 TB"
  }
  validation {
    condition     = var.q_cluster_soft_capacity_limit <= 500 * length(var.persistent_storage.bucket)
    error_message = "The maximum value for q_cluster_soft_capacity_limit is 500TB per object storage bucket. Please add more buckets before increasing the capacity beyond the current supported maximum value of ${500 * length(var.persistent_storage.bucket)}TB"
  }
}

variable "q_node_count" {
  description = "The number of Qumulo nodes to deploy."
  type        = number
  default     = 3
  validation {
    condition     = var.q_node_count >= 1
    error_message = "Node count must be at least 1."
  }
  validation {
    condition     = var.q_node_count <= 24
    error_message = "Node count must be less than or equal to 24."
  }
}

variable "q_cluster_node_count" {
  description = "The number of Qumulo nodes to create the cluster with."
  type        = number
  default     = 3
  validation {
    condition = anytrue([
      var.dev_environment,
      var.q_cluster_node_count != 2 && var.q_cluster_node_count != 4,
    ])
    error_message = "Clusters with 2 or 4 nodes cannot be created with fault domain tolerance and are therefore not allowed"
  }
  validation {
    condition     = var.q_cluster_node_count <= 24
    error_message = "Cluster node count must be less than or equal to 24."
  }
}

variable "q_cluster_cold" {
  description = "Creates a cold cluster, which tiers long-lived data to the infrequent access object storage tier."
  type        = bool
  default     = false
}

variable "dev_environment" {
  description = "Enables the use of instance shapes other than DenseIO E4 and E5 and allows for nodes to be unclustered. NOT recommended for production."
  type        = bool
  default     = false
}

variable "single_fault_domain" {
  description = "The name of a single fault domain to place all nodes in. Leave null to distribute across fault domains."
  type        = string
  nullable    = true
  default     = null
}

variable "node_instance_shape" {
  description = "The VM shape to use for the Qumulo nodes."
  type        = string
  default     = "VM.DenseIO.E4.Flex"
  validation {
    condition = anytrue([
      var.dev_environment,
      var.node_instance_shape == "VM.DenseIO.E4.Flex",
      var.node_instance_shape == "VM.DenseIO.E5.Flex"
    ])
    error_message = "Only VM shapes with local disks are supported (DenseIO E4 and E5)."
  }
}

variable "node_instance_ocpus" {
  description = "The number of OCPUs to use for Qumulo node VMs."
  type        = number
  default     = 8
}

variable "node_base_image" {
  description = "The OCID of the image used to launch node instances. Must be compatible with the chosen node instance shape. Leave null to use the latest release Oracle Linux 9 image."
  type        = string
  nullable    = true
}

variable "assign_public_ip" {
  description = "Enable/disable the use of public IP addresses on the cluster and provisioning node."
  type        = bool
  default     = false
  nullable    = false
}

variable "block_volume_count" {
  description = "The number of block volumes to create each node with. These are largely performance resources. Defaults to half of instance ocpus if unset."
  type        = number
  default     = null
  validation {
    condition     = var.block_volume_count != null ? var.block_volume_count >= 3 : true
    error_message = "A minimum of 3 disks are required per node."
  }
}

variable "block_volume_encryption_key" {
  description = "The OCID of the Master Encryption Key to use for block volume encryption at rest."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.block_volume_encryption_key == null || substr(var.block_volume_encryption_key, 0, 14) == "ocid1.key.oc1."
    error_message = "block_volume_encryption_key must either be null or begin with ocid1.key.oc1."
  }
}

variable "vault_ocid" {
  description = "The OCID of an existing vault to be used to store the cluster secrets."
  type        = string
  nullable    = false
  validation {
    condition     = substr(var.vault_ocid, 0, 16) == "ocid1.vault.oc1."
    error_message = "The vault ocid should start with ocid1.vault.oc1."
  }
}

variable "qumulo_core_rpm_url" {
  description = "A URL accessible to the instances pointing to the qumulo-core.rpm object for the version of Qumulo you want to install."
  type        = string
  nullable    = false
}

variable "q_cluster_admin_password" {
  description = "The admin password for the Qumulo cluster."
  type        = string
  nullable    = false
  sensitive   = true
  validation {
    condition     = can(regex("^(.{0,7}|[^0-9]*|[^A-Z]*|[^a-z]*)$", var.q_cluster_admin_password)) ? false : true
    error_message = "The admin password must be at least 8 characters and contain an uppercase, lowercase, and number."
  }
}

variable "q_cluster_floating_ips" {
  description = "The number of floating ips associated with the Qumulo cluster."
  type        = number
  default     = 3
  validation {
    condition     = var.q_cluster_floating_ips == 0 || (var.q_cluster_floating_ips >= var.q_node_count && var.q_cluster_floating_ips <= ceil(var.q_node_count / 2) * 31)
    error_message = "The number of floating ips must be at least the number of nodes and cannot exceed 31 per node with half of the nodes down. Set to 0 for no floating IPs."
  }
}

variable "availability_domain" {
  description = "The availability domain to be used for the cluster resources. Leave null to use the default."
  type        = string
  default     = null
}

variable "create_identity_resources" {
  description = "If true, will create identity resources for instances.  Otherwise assumes resources are pre-deployed."
  type        = bool
  nullable    = false
  default     = true
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

variable "vault_key_ocid" {
  description = "The ocid of the vault key to be used for encrypting secrets related to the deployment."
  type        = string
  nullable    = true
  default     = null
  validation {
    condition = (
      var.vault_ocid != null && (var.vault_key_ocid == null ? true : substr(var.vault_key_ocid, 0, 14) == "ocid1.key.oc1.")
    )
    error_message = "A vault ocid must be supplied and the vault key ocid should start with ocid1.key.oc1."
  }
}

variable "provisioner_instance_shape" {
  description = "The VM shape to use for the provisioner instance."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "provisioner_instance_ocpus" {
  description = "The number of OCPUs to use for the provisioner instance."
  type        = number
  default     = 2
}

variable "object_storage_access_delay" {
  description = "The time in seconds to delay accessing object storage after initial boot to wait for transient access errors to stop."
  type        = number
  default     = 300
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

variable "multi_ad_deployment" {
  description = "If true, spread nodes across availability domains; otherwise spread across fault domains in the first availability domain."
  type        = bool
  default     = false

  validation {
    condition = (
      var.multi_ad_deployment
      ? length(data.oci_identity_availability_domains.ads.availability_domains) >= 1
      : length(data.oci_identity_fault_domains.by_availability_domain[var.availability_domain != null ? var.availability_domain : data.oci_identity_availability_domains.ads.availability_domains[0].name].fault_domains) >= 1
    )
    error_message = "Placement requirement not met: region must have >= 1 availability domain (multi_ad_deployment=true) or the selected/default single availability domain must have >= 1 fault domain (multi_ad_deployment=false)."
  }
  validation {
    condition     = !var.multi_ad_deployment || var.availability_domain == null
    error_message = "availability_domain must be null when multi_ad_deployment is true; a single explicit availability domain cannot be combined with multi-AD placement."
  }
}

variable "provisioner_wait_for_completion_max_retries" {
  description = "The maximum number of retries to wait for the provisioner to complete."
  type        = number
  default     = 60
}