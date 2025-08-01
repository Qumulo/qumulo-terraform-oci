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

variable "subnet_ocid" {
  description = "The ocid of the subnet which the Qumulo cluster should be created within."
  type        = string
}

variable "node_count" {
  description = "The number of Qumulo nodes to create the cluster with."
  type        = number
}

variable "permanent_disk_count" {
  description = "The number of permanent disks per node with which to create the cluster."
  type        = number
}

variable "floating_ip_count" {
  description = "The number of floating IP addresses with which to create the cluster."
  type        = number
}

variable "persisted_node_count" {
  description = "The number of Qumulo nodes in the already created cluster."
  type        = number
}

variable "persisted_disk_count" {
  description = "The number of permanent disks per node in the already created cluster."
  type        = number
}

variable "node_instance_shape" {
  description = "The VM shape to use for the Qumulo nodes."
  type        = string
}

variable "node_instance_ocpus" {
  description = "The number of OCPUs to use for Qumulo node VMs."
  type        = number
}

variable "assign_public_ip" {
  description = "Enable/disable the use of public IP addresses on the cluster and provisioning node.  Cluster still requires outbound internet access to function."
  type        = bool
  default     = true
  nullable    = false
}

variable "node_ssh_public_key_paths" {
  description = "A list of the local paths to files containing the public keys which should be authorized to ssh into the Qumulo nodes."
  type        = list(string)
}

variable "node_ssh_public_key_strings" {
  description = "A list of the public keys which should be authorized to ssh into the Qumulo nodes."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "qumulo_core_object_uri" {
  description = "The URI of the object that contains the qumulo core package."
  type        = string
}

variable "availability_domain" {
  description = "The availability domain to be used for the cluster resources."
  type        = string
}

variable "object_storage_uris" {
  description = "The URIs of Oracle object storage that are backing the Qumulo cluster."
  type        = string
}

variable "access_key_id" {
  description = "The id of the secret key that has access to the cluster's object storage."
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "The secret key that has access to the cluster's object storage."
  type        = string
  sensitive   = true
}

variable "object_storage_access_delay" {
  description = "The time in seconds to delay accessing object storage after initial boot to wait for transient access errors to stop."
  type        = number
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
