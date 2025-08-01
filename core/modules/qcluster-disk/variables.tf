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

variable "disk_count" {
  description = "The number of disks per node with which to create the cluster."
  type        = string
}

variable "persisted_disk_count" {
  description = "The number of permanent disks per node in the already created cluster."
  type        = number
}

variable "availability_domain" {
  description = "The availability domain to be used for the cluster resources."
  type        = string
}

variable "compartment_ocid" {
  description = "The ocid of the compartment in which the Qumulo cluster is created."
  type        = string
}

variable "deployment_unique_name" {
  description = "The unique deployment name of your qumulo cluster."
  type        = string
}

variable "size_in_gbs" {
  description = "The size of each disk in gbs."
  type        = string
}

variable "vpus_per_gb" {
  description = "The number of vpus per gb of the disk size."
  type        = string
}

variable "node_id" {
  description = "The index of the node on which to create the disks."
  type        = number
}

variable "instance_id" {
  description = "The ocid of the node on which to create the disks."
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
