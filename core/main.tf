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

moved {
  from = oci_identity_domains_user.domain_cluster_user[0]
  to   = module.identity[0].oci_identity_domains_user.domain_cluster_user[0]
}

moved {
  from = oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0]
  to   = module.identity[0].oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0]
}
moved {
  from = oci_identity_domains_group.domain_cluster_identity_group[0]
  to   = module.identity[0].oci_identity_domains_group.domain_cluster_identity_group[0]
}

moved {
  from = oci_identity_policy.domain_cluster_policy[0]
  to   = module.identity[0].oci_identity_policy.domain_cluster_policy[0]
}

moved {
  from = oci_identity_user.classic_cluster_user[0]
  to   = module.identity[0].oci_identity_user.classic_cluster_user[0]
}

moved {
  from = oci_identity_customer_secret_key.classic_cluster_secret_key[0]
  to   = module.identity[0].oci_identity_customer_secret_key.classic_cluster_secret_key[0]
}

moved {
  from = oci_identity_group.classic_cluster_identity_group[0]
  to   = module.identity[0].oci_identity_group.classic_cluster_identity_group[0]
}

moved {
  from = oci_identity_user_group_membership.classic_cluster_group_membership[0]
  to   = module.identity[0].oci_identity_user_group_membership.classic_cluster_group_membership[0]
}

moved {
  from = oci_identity_policy.classic_cluster_policy[0]
  to   = module.identity[0].oci_identity_policy.classic_cluster_policy[0]
}


resource "null_resource" "vault_lock" {
  triggers = {
    deployment_vault_ocid = var.vault_ocid
  }

  lifecycle { ignore_changes = all }
}

resource "null_resource" "name_lock" {
  triggers = {
    deployment_unique_name = "${var.q_cluster_name}-${var.persistent_storage.deployment_id}"
  }

  lifecycle { ignore_changes = all }
}


# Vault Master Encryption Key
#   Skipped if vault_key_ocid is provided
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

# Identity resources
module "identity" {
  source = "./modules/identity"

  providers = {
    oci             = oci
    oci.home-region = oci.home-region
  }

  count = var.create_identity_resources ? 1 : 0

  deployment_unique_name              = local.deployment_unique_name
  cluster_email                       = local.cluster_email
  tenancy_ocid                        = var.tenancy_ocid
  compartment_ocid                    = var.compartment_ocid
  persistent_storage_access_model     = var.persistent_storage_access_model
  subnet_compartment_id               = data.oci_core_subnet.cluster_subnet.compartment_id
  persistent_storage_compartment_ocid = var.persistent_storage.compartment_ocid
  persistent_storage_bucket_prefix    = var.persistent_storage.bucket_prefix
  defined_tags                        = var.defined_tags
  freeform_tags                       = var.freeform_tags
}

# Cluster nodes
module "qcluster" {
  source = "./modules/qcluster"

  deployment_unique_name = local.deployment_unique_name

  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  node_count                  = var.q_node_count
  permanent_disk_count        = local.permanent_disk_count
  block_volume_encryption_key = var.block_volume_encryption_key
  floating_ip_count           = var.q_cluster_floating_ips
  persisted_node_count        = tonumber(data.external.cluster_node_count.result.value)
  persisted_disk_count        = tonumber(data.external.deployed_permanent_disk_count.result.value)

  node_instance_shape = var.node_instance_shape
  node_instance_ocpus = var.node_instance_ocpus
  node_base_image     = local.node_base_image
  assign_public_ip    = var.assign_public_ip

  node_ssh_public_key_paths   = var.node_ssh_public_key_paths
  node_ssh_public_key_strings = var.node_ssh_public_key_strings

  qumulo_core_object_uri = var.qumulo_core_rpm_url

  multi_ad_deployment       = var.multi_ad_deployment
  availability_domain       = var.availability_domain
  availability_domain_names = local.availability_domain_names
  single_fault_domain       = var.single_fault_domain

  object_storage_uris         = local.object_storage_uris
  access_key_id               = local.access_key_id
  secret_key                  = local.secret_key
  object_storage_access_delay = var.object_storage_access_delay

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  depends_on = [
    module.identity[0]
  ]

}

# Cluster provisioning management server
module "qprovisioner" {
  source = "./modules/qprovisioner"

  cluster_name = var.q_cluster_name

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  node_count                  = var.q_cluster_node_count
  permanent_disk_count        = local.permanent_disk_count
  instance_shape              = var.provisioner_instance_shape
  instance_ocpus              = var.provisioner_instance_ocpus
  assign_public_ip            = var.assign_public_ip
  block_volume_encryption_key = var.block_volume_encryption_key

  instance_ssh_public_key_paths   = var.node_ssh_public_key_paths
  instance_ssh_public_key_strings = var.node_ssh_public_key_strings

  cluster_node_ip_addresses                   = local.cluster_node_ips
  clustering_node_ocid                        = local.clustering_node_id
  clustering_node_ip_address                  = local.clustering_node_ip
  node_ip_addresses_and_fault_domains         = local.node_ips_and_fault_domains
  object_storage_uris                         = local.object_storage_uris
  soft_capacity_limit                         = var.q_cluster_soft_capacity_limit
  product_type                                = local.product_type
  secret_ocid                                 = oci_vault_secret.customer_secret_key_secret.id
  admin_password                              = var.q_cluster_admin_password
  floating_ip_addresses                       = module.qcluster.floating_ips
  netmask                                     = data.oci_core_subnet.subnet.cidr_block
  cluster_node_count_secret_id                = oci_vault_secret.cluster_node_count.id
  deployed_permanent_disk_count_secret_id     = oci_vault_secret.deployed_permanent_disk_count.id
  cluster_soft_capacity_limit_secret_id       = oci_vault_secret.cluster_soft_capacity_limit.id
  provisioner_complete_secret_id              = oci_vault_secret.provisioner_complete.id
  provisioner_wait_for_completion_max_retries = var.provisioner_wait_for_completion_max_retries

  dev_environment = var.dev_environment
  defined_tags    = var.defined_tags
  freeform_tags   = var.freeform_tags
}
