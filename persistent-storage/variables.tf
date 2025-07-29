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

variable "persistent_storage_vault_ocid" {
  description = "The OCID of an existing vault to be used to store secrets from the persistent storage."
  type        = string
  nullable    = false
  validation {
    condition     = substr(var.persistent_storage_vault_ocid, 0, 16) == "ocid1.vault.oc1."
    error_message = "The persistent storage vault ocid should start with ocid1.vault.oc1."
  }
}

variable "vault_key_ocid" {
  description = "The ocid of the vault key to be used for encrypting secrets related to the deployment."
  type        = string
  nullable    = true
  default     = null
  validation {
    condition = (
      var.persistent_storage_vault_ocid != null && (var.vault_key_ocid == null ? true : substr(var.vault_key_ocid, 0, 14) == "ocid1.key.oc1.")
    )
    error_message = "A vault ocid must be supplied and the vault key ocid should start with ocid1.key.oc1."
  }
}

variable "compartment_ocid" {
  description = "The compartment into which you want your persistent storage deployed."
  type        = string
  nullable    = false
  validation {
    condition     = substr(var.compartment_ocid, 0, 22) == "ocid1.compartment.oc1."
    error_message = "The compartment ocid should start with ocid1.compartment.oc1."
  }
}

variable "object_storage_bucket_count" {
  description = "The number of object storage buckets to deploy."
  type        = number
  default     = 16
  nullable    = false
  validation {
    condition     = var.object_storage_bucket_count >= 1
    error_message = "object_storage_bucket_count must be at least 1"
  }
}

variable "region" {
  description = "The OCI region that you want to deploy into. EX: us-phoenix-1"
  type        = string
  nullable    = false
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
