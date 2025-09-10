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

# **** Version 2.0 ****

module "core" {
  source = "./core/"

  dev_environment                          = var.dev_environment
  persistent_storage                       = local.persistent_storage
  node_ssh_public_key_paths                = var.node_ssh_public_key_paths
  node_ssh_public_key_strings              = var.node_ssh_public_key_strings
  tenancy_ocid                             = var.tenancy_ocid
  compartment_ocid                         = var.compartment_ocid
  subnet_ocid                              = var.subnet_ocid
  q_cluster_name                           = var.q_cluster_name
  q_cluster_soft_capacity_limit            = var.q_cluster_soft_capacity_limit
  q_node_count                             = var.q_node_count
  q_cluster_node_count                     = var.q_cluster_node_count
  q_cluster_cold                           = var.q_cluster_cold
  node_instance_shape                      = var.node_instance_shape
  node_instance_ocpus                      = var.node_instance_ocpus
  assign_public_ip                         = var.assign_public_ip
  block_volume_count                       = var.block_volume_count
  vault_ocid                               = var.vault_ocid
  qumulo_core_rpm_url                      = var.qumulo_core_rpm_url
  q_cluster_admin_password                 = var.q_cluster_admin_password
  q_cluster_floating_ips                   = var.q_cluster_floating_ips
  availability_domain                      = var.availability_domain
  create_dynamic_group_and_identity_policy = var.create_dynamic_group_and_identity_policy
  custom_secret_key_id                     = var.custom_secret_key_id
  custom_secret_key                        = var.custom_secret_key
  vault_key_ocid                           = var.vault_key_ocid
  provisioner_instance_shape               = var.provisioner_instance_shape
  provisioner_instance_ocpus               = var.provisioner_instance_ocpus
  object_storage_access_delay              = var.object_storage_access_delay
  defined_tags                             = var.defined_tags
  freeform_tags                            = var.freeform_tags
}

