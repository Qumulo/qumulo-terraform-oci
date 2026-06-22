/*
 * MIT License
 *
 * Copyright (c) 2026 Qumulo
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

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_identity_fault_domains" "by_availability_domain" {
  for_each = { for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name => ad }

  compartment_id      = var.compartment_ocid
  availability_domain = each.key
}

data "oci_kms_vault" "deployment_vault" {
  vault_id = null_resource.vault_lock.triggers.deployment_vault_ocid
}

data "oci_core_subnet" "cluster_subnet" {
  subnet_id = var.subnet_ocid
}

# This item acts a barrier to prevent inadvertant node removal before the cluster has successfully removed nodes from membership
data "external" "cluster_node_count" {
  program = concat(local.retrieve_stored_value_sh, [oci_vault_secret.cluster_node_count.id])
}

data "external" "deployed_permanent_disk_count" {
  program = concat(local.retrieve_stored_value_sh, [oci_vault_secret.deployed_permanent_disk_count.id])
}

data "external" "cluster_soft_capacity_limit" {
  program = concat(local.retrieve_stored_value_sh, [oci_vault_secret.cluster_soft_capacity_limit.id])

  lifecycle {
    postcondition {
      condition     = tonumber(self.result.value) <= var.q_cluster_soft_capacity_limit
      error_message = "Decreasing cluster soft capacity limit is not supported."
    }
  }
}

data "oci_core_subnet" "subnet" {
  subnet_id = var.subnet_ocid
}

data "oci_core_images" "latest" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.node_instance_shape
  state                    = "AVAILABLE"
  sort_by                  = "DISPLAYNAME"
  sort_order               = "DESC"
}

