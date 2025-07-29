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

variable "cluster_name" {
  description = "The name of your qumulo cluster."
  type        = string
}

variable "compartment_ocid" {
  description = "The ocid of the compartment in which the Qumulo cluster is created."
  type        = string
}

variable "subnet_ocid" {
  description = "The ocid of the subnet in which the Qumulo cluster is created"
  type        = string
}

variable "node_count" {
  description = "The number of Qumulo nodes to create the cluster with."
  type        = number
}

variable "soft_capacity_limit" {
  description = "The soft capacity limit of the qumulo cluster, in TiB"
  type        = number
}

variable "permanent_disk_count" {
  description = "The number of permanent disks per node with which to create the cluster."
  type        = number
}

variable "instance_shape" {
  description = "The VM shape to use for the provisioner instance."
  type        = string
}

variable "instance_ocpus" {
  description = "The number of OCPUs to use for the provisioner node."
  type        = number
}

variable "assign_public_ip" {
  description = "Enable/disable the use of public IP addresses on the cluster and provisioning node.  Cluster still requires outbound internet access to function."
  type        = bool
  default     = true
  nullable    = false
}

variable "instance_ssh_public_key_paths" {
  description = "A list of the local paths to files containing the public keys which should be authorized to ssh into the provisioner instance."
  type        = list(string)
}

variable "instance_ssh_public_key_strings" {
  description = "A list of the public keys which should be authorized to ssh into the Qumulo nodes."
  type        = list(string)
}

variable "cluster_node_ip_addresses" {
  description = "The private IP addresses for the nodes in the Qumulo cluster."
  type        = string
}

variable "clustering_node_ocid" {
  description = "The id of the node that will start the cluster creation."
  type        = string
}

variable "clustering_node_ip_address" {
  description = "The ip of the node that will start the cluster creation."
  type        = string
}

variable "node_ip_addresses_and_fault_domains" {
  description = "The private ips and fault domains for the nodes in the Qumulo cluster."
  type        = string
}

variable "object_storage_uris" {
  description = "The URIs of Oracle object storage that are backing the Qumulo cluster."
  type        = string
}

variable "product_type" {
  description = "The product type of the new cluster. Supported values are ACTIVE_WITH_STANDARD_STORAGE and ARCHIVE_WITH_IA_STORAGE."
  type        = string
  validation {
    condition = anytrue([
      var.product_type == "ACTIVE_WITH_STANDARD_STORAGE",
      var.product_type == "ARCHIVE_WITH_IA_STORAGE",
    ])
    error_message = "The product type must be one of ACTIVE_WITH_STANDARD_STORAGE or ARCHIVE_WITH_IA_STORAGE."
  }
}

variable "admin_password" {
  description = "The password that will be used for the default admin user."
  type        = string
  sensitive   = true
}

variable "secret_ocid" {
  description = "The id of the secret that contains the object storage access key in the key vault."
  type        = string
}

variable "floating_ip_addresses" {
  description = "List of floating ip addresses for the cluster."
  type        = string
}

variable "netmask" {
  description = "The cidr block of the cluster's subnet."
  type        = string
}

variable "cluster_node_count_secret_id" {
  description = "The id of the vault secret in which we store the cluster node count."
  type        = string
}

variable "deployed_permanent_disk_count_secret_id" {
  description = "The id of the vault secret in which we store the deployed permanent disk count."
  type        = string
}

variable "cluster_soft_capacity_limit_secret_id" {
  description = "The id of the vault secret in which we store the cluster soft capacity limit."
  type        = string
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

variable "dev_environment" {
  description = "Enables the use of instance shapes other than DenseIO E4 and E5 and allows for nodes to be unclustered. NOT recommended for production."
  type        = bool
  default     = false
}
