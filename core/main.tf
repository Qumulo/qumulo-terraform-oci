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

resource "null_resource" "vault_lock" {
  triggers = {
    deployment_vault_ocid = var.vault_ocid
  }

  lifecycle { ignore_changes = all }
}

data "oci_kms_vault" "deployment_vault" {
  vault_id = null_resource.vault_lock.triggers.deployment_vault_ocid
}

data "oci_core_subnet" "cluster_subnet" {
  subnet_id = var.subnet_ocid
}

locals {
  vault = data.oci_kms_vault.deployment_vault
}

resource "random_uuid" "deployment_id" {
}

resource "null_resource" "name_lock" {
  triggers = {
    deployment_unique_name = "${var.q_cluster_name}-${random_uuid.deployment_id.result}"
  }

  lifecycle { ignore_changes = all }
}

locals {
  cluster_email          = "${local.deployment_unique_name}-user@qumulo.com"
  deployment_unique_name = null_resource.name_lock.triggers.deployment_unique_name
}

resource "oci_identity_user" "cluster_user" {
  count          = var.custom_secret_key_id == null ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "${local.deployment_unique_name}-user"
  description    = "The user used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  email          = local.cluster_email
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_customer_secret_key" "cluster_secret_key" {
  count        = var.custom_secret_key_id == null ? 1 : 0
  user_id      = oci_identity_user.cluster_user[0].id
  display_name = "${local.deployment_unique_name}-secret-key"
}

resource "oci_identity_group" "cluster_identity_group" {
  count          = var.custom_secret_key_id == null ? 1 : 0
  compartment_id = var.tenancy_ocid
  description    = "The identity group used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${local.deployment_unique_name}-identity-group"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_user_group_membership" "cluster_group_membership" {
  count    = var.custom_secret_key_id == null ? 1 : 0
  group_id = oci_identity_group.cluster_identity_group[0].id
  user_id  = oci_identity_user.cluster_user[0].id
}

resource "oci_identity_policy" "cluster_policy" {
  count          = var.custom_secret_key_id == null ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${local.deployment_unique_name}-cluster-identity-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow group ${oci_identity_group.cluster_identity_group[0].name} to manage object-family in compartment id ${var.persistent_storage.compartment_ocid} where target.bucket.name = /${var.persistent_storage.bucket_prefix}-bucket-*/"
  ]
}


resource "oci_identity_dynamic_group" "instance_dynamic_group" {
  count          = var.create_dynamic_group_and_identity_policy ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "${local.deployment_unique_name}-instance-dynamic-group"
  description    = "The dynamic group used by the ${local.deployment_unique_name} Qumulo cluster to obtain instance privileges."
  matching_rule  = "instance.compartment.id = '${var.compartment_ocid}'"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_policy" "instance_policy" {
  count          = var.create_dynamic_group_and_identity_policy ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to retrieve and manage resources related to the instances."
  name           = "${local.deployment_unique_name}-instance-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_dynamic_group[0].name} to read secret-bundles in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_dynamic_group[0].name} to use secrets in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_dynamic_group[0].name} to use instances in compartment id ${var.compartment_ocid}"
  ]
}

resource "oci_identity_policy" "subnet_policy" {
  count          = var.create_dynamic_group_and_identity_policy ? 1 : 0
  compartment_id = data.oci_core_subnet.cluster_subnet.compartment_id
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to manage resources related to the host subnet."
  name           = "${local.deployment_unique_name}-subnet-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_dynamic_group[0].name} to use virtual-network-family in compartment id ${data.oci_core_subnet.cluster_subnet.compartment_id}",
  ]
}


resource "oci_kms_key" "vault_key" {
  count          = var.vault_key_ocid == null ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${local.deployment_unique_name}-vault-key"
  key_shape {
    algorithm = "AES"
    length    = 32
  }
  management_endpoint = local.vault.management_endpoint
  defined_tags        = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags       = var.freeform_tags
}

locals {
  access_key_id            = sensitive(var.custom_secret_key_id != null ? var.custom_secret_key_id : oci_identity_customer_secret_key.cluster_secret_key[0].id)
  secret_key               = sensitive(var.custom_secret_key != null ? var.custom_secret_key : oci_identity_customer_secret_key.cluster_secret_key[0].key)
  retrieve_stored_value_sh = ["${path.module}/scripts/retrieve_stored_value.sh"]
  vault_key_ocid           = var.vault_key_ocid != null ? var.vault_key_ocid : oci_kms_key.vault_key[0].id
}

resource "oci_vault_secret" "cluster_node_count" {
  compartment_id = var.compartment_ocid
  key_id         = local.vault_key_ocid
  secret_name    = "${local.deployment_unique_name}-cluster-node-count"
  vault_id       = local.vault.id
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  # This is only a default value
  secret_content {
    content_type = "base64"
    content      = base64encode(jsonencode(0))
  }

  lifecycle {
    ignore_changes = [
      # This is modified by the provisioner, do not overwrite it
      secret_content,
    ]
  }
}

# This item acts a barrier to prevent inadvertant node removal before the cluster has successfully removed nodes from membership
data "external" "cluster_node_count" {
  program = concat(local.retrieve_stored_value_sh, [oci_vault_secret.cluster_node_count.id])
}

resource "oci_vault_secret" "deployed_permanent_disk_count" {
  compartment_id = var.compartment_ocid
  key_id         = local.vault_key_ocid
  secret_name    = "${local.deployment_unique_name}-deployed-permanent-disk-count"
  vault_id       = local.vault.id
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  # This is only a default value
  secret_content {
    content_type = "base64"
    content      = base64encode(jsonencode(0))
  }

  lifecycle {
    ignore_changes = [
      # This is modified by the provisioner, do not overwrite it
      secret_content,
    ]
  }
}

data "external" "deployed_permanent_disk_count" {
  program = concat(local.retrieve_stored_value_sh, [oci_vault_secret.deployed_permanent_disk_count.id])
}

resource "oci_vault_secret" "cluster_soft_capacity_limit" {
  compartment_id = var.compartment_ocid
  key_id         = local.vault_key_ocid
  secret_name    = "${local.deployment_unique_name}-cluster-soft-capacity-limit"
  vault_id       = local.vault.id
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  # This is only a default value
  secret_content {
    content_type = "base64"
    content      = base64encode(jsonencode(0))
  }

  lifecycle {
    ignore_changes = [
      # This is modified by the provisioner, do not overwrite it
      secret_content,
    ]
  }
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

resource "oci_vault_secret" "customer_secret_key_secret" {
  compartment_id = var.compartment_ocid
  key_id         = local.vault_key_ocid
  secret_name    = "${local.deployment_unique_name}-customer-secret-key"
  vault_id       = local.vault.id
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  secret_content {
    content_type = "base64"
    content = base64encode(jsonencode({
      access_key_id = local.access_key_id
      secret_key    = local.secret_key
    }))
  }
}

resource "oci_vault_secret" "provisioner_complete" {
  compartment_id = var.compartment_ocid
  key_id         = local.vault_key_ocid
  secret_name    = "${local.deployment_unique_name}-provisioner-complete"
  vault_id       = local.vault.id
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  # This value is set on every terraform run until the provisioner sets it to "true"
  secret_content {
    content_type = "base64"
    content      = base64encode(jsonencode(false))
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

locals {
  node_base_image = var.node_base_image != null ? var.node_base_image : data.oci_core_images.latest.images[0].id
}

module "qcluster" {
  source = "./modules/qcluster"

  deployment_unique_name = local.deployment_unique_name

  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  node_count           = var.q_node_count
  permanent_disk_count = local.permanent_disk_count
  floating_ip_count    = var.q_cluster_floating_ips
  persisted_node_count = tonumber(data.external.cluster_node_count.result.value)
  persisted_disk_count = tonumber(data.external.deployed_permanent_disk_count.result.value)

  node_instance_shape = var.node_instance_shape
  node_instance_ocpus = var.node_instance_ocpus
  node_base_image     = local.node_base_image
  assign_public_ip    = var.assign_public_ip

  node_ssh_public_key_paths   = var.node_ssh_public_key_paths
  node_ssh_public_key_strings = var.node_ssh_public_key_strings

  qumulo_core_object_uri = var.qumulo_core_rpm_url

  availability_domain = var.availability_domain

  object_storage_uris         = local.object_storage_uris
  access_key_id               = var.custom_secret_key == null ? local.access_key_id : ""
  secret_key                  = var.custom_secret_key == null ? local.secret_key : ""
  object_storage_access_delay = var.object_storage_access_delay

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  depends_on = [
    oci_identity_policy.cluster_policy,
    oci_identity_policy.instance_policy
  ]
}

module "qprovisioner" {
  source = "./modules/qprovisioner"

  cluster_name = var.q_cluster_name

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  node_count           = var.q_cluster_node_count
  permanent_disk_count = local.permanent_disk_count
  instance_shape       = var.provisioner_instance_shape
  instance_ocpus       = var.provisioner_instance_ocpus
  assign_public_ip     = var.assign_public_ip

  instance_ssh_public_key_paths   = var.node_ssh_public_key_paths
  instance_ssh_public_key_strings = var.node_ssh_public_key_strings

  cluster_node_ip_addresses               = local.cluster_node_ips
  clustering_node_ocid                    = local.clustering_node_id
  clustering_node_ip_address              = local.clustering_node_ip
  node_ip_addresses_and_fault_domains     = local.node_ips_and_fault_domains
  object_storage_uris                     = local.object_storage_uris
  soft_capacity_limit                     = var.q_cluster_soft_capacity_limit
  product_type                            = local.product_type
  secret_ocid                             = oci_vault_secret.customer_secret_key_secret.id
  admin_password                          = var.q_cluster_admin_password
  floating_ip_addresses                   = module.qcluster.floating_ips
  netmask                                 = data.oci_core_subnet.subnet.cidr_block
  cluster_node_count_secret_id            = oci_vault_secret.cluster_node_count.id
  deployed_permanent_disk_count_secret_id = oci_vault_secret.deployed_permanent_disk_count.id
  cluster_soft_capacity_limit_secret_id   = oci_vault_secret.cluster_soft_capacity_limit.id
  provisioner_complete_secret_id          = oci_vault_secret.provisioner_complete.id

  dev_environment = var.dev_environment
  defined_tags    = var.defined_tags
  freeform_tags   = var.freeform_tags
}
