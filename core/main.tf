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

# Directives to help migration from older versions of the module
moved {
  from = oci_identity_user.cluster_user
  to   = oci_identity_user.classic_cluster_user
}

moved {
  from = oci_identity_customer_secret_key.cluster_secret_key
  to   = oci_identity_customer_secret_key.classic_cluster_secret_key
}

moved {
  from = oci_identity_group.cluster_identity_group
  to   = oci_identity_group.classic_cluster_identity_group
}

moved {
  from = oci_identity_user_group_membership.cluster_group_membership
  to   = oci_identity_user_group_membership.classic_cluster_group_membership
}

moved {
  from = oci_identity_policy.cluster_policy
  to   = oci_identity_policy.classic_cluster_policy
}

# Classic access model Resources
resource "oci_identity_user" "classic_cluster_user" {
  provider       = oci.home-region
  count          = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "${local.deployment_unique_name}-user"
  description    = "The user used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  email          = local.cluster_email
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_customer_secret_key" "classic_cluster_secret_key" {
  provider     = oci.home-region
  count        = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  user_id      = oci_identity_user.classic_cluster_user[0].id
  display_name = "${local.deployment_unique_name}-secret-key"
}

resource "oci_identity_group" "classic_cluster_identity_group" {
  provider       = oci.home-region
  count          = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  compartment_id = var.tenancy_ocid
  description    = "The identity group used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${local.deployment_unique_name}-identity-group"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_user_group_membership" "classic_cluster_group_membership" {
  provider = oci.home-region
  count    = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  group_id = oci_identity_group.classic_cluster_identity_group[0].id
  user_id  = oci_identity_user.classic_cluster_user[0].id
}

resource "oci_identity_policy" "classic_cluster_policy" {
  provider       = oci.home-region
  count          = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${local.deployment_unique_name}-cluster-identity-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow group ${oci_identity_group.classic_cluster_identity_group[0].name} to manage object-family in compartment id ${var.persistent_storage.compartment_ocid} where target.bucket.name = /${var.persistent_storage.bucket_prefix}-bucket-*/"
  ]
}


# Domain access model Resources
locals {
  idc_defined_tag_list = [
    for k, v in var.defined_tags : {
      namespace = split(".", k)[0]
      key       = trimprefix(k, "${split(".", k)[0]}.")
      value     = v
    }
  ]
  idc_freeform_tag_list = [
    for k, v in var.freeform_tags : {
      key   = k
      value = v
    }
  ]
}

resource "oci_identity_domains_user" "domain_cluster_user" {
  provider = oci.home-region
  count    = var.persistent_storage_access_model.access_style == "domain" ? 1 : 0

  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User",
  ]
  attributes    = "tags"
  idcs_endpoint = var.persistent_storage_access_model.domain_idcs_endpoint
  user_name     = "${local.deployment_unique_name}-user"
  description   = "The user used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  user_type     = "Service"
  name {
    given_name  = local.deployment_unique_name
    family_name = "qumulo"
  }
  emails {
    value   = local.cluster_email
    type    = "work"
    primary = true
  }
  urnietfparamsscimschemasoracleidcsextensioncapabilities_user {
    can_use_api_keys                 = false
    can_use_auth_tokens              = false
    can_use_console                  = false
    can_use_console_password         = false
    can_use_customer_secret_keys     = true
    can_use_db_credentials           = false
    can_use_oauth2client_credentials = false
    can_use_smtp_credentials         = false
  }
  urnietfparamsscimschemasoracleidcsextension_oci_tags {
    dynamic "defined_tags" {
      for_each = { for i, t in local.idc_defined_tag_list : "${t.namespace}.${t.key}" => t }
      content {
        namespace = defined_tags.value.namespace
        key       = defined_tags.value.key
        value     = defined_tags.value.value
      }
    }

    dynamic "freeform_tags" {
      for_each = { for t in local.idc_freeform_tag_list : t.key => t }
      content {
        key   = freeform_tags.value.key
        value = freeform_tags.value.value
      }
    }
  }
  lifecycle {
    ignore_changes = [
      schemas,
      attributes,
      idcs_endpoint,
      user_name,
      emails,
      description,
      user_type,
      name,
      urnietfparamsscimschemasoracleidcsextensioncapabilities_user,
      urnietfparamsscimschemasoracleidcsextension_oci_tags
    ]
  }
}

resource "oci_identity_domains_customer_secret_key" "domain_cluster_secret_key" {
  provider      = oci.home-region
  count         = var.persistent_storage_access_model.access_style == "domain" ? 1 : 0
  idcs_endpoint = var.persistent_storage_access_model.domain_idcs_endpoint
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:customerSecretKey"]
  display_name  = "${local.deployment_unique_name}-secret-key"
  user {
    value = oci_identity_domains_user.domain_cluster_user[0].id
  }
}

resource "oci_identity_domains_group" "domain_cluster_identity_group" {
  provider = oci.home-region
  count    = var.persistent_storage_access_model.access_style == "domain" ? 1 : 0
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:Group",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
  ]
  attributes    = "members,tags"
  idcs_endpoint = var.persistent_storage_access_model.domain_idcs_endpoint
  display_name  = "${local.deployment_unique_name}-domain-identity-group"

  members {
    type  = "User"
    value = oci_identity_domains_user.domain_cluster_user[0].id
  }
  urnietfparamsscimschemasoracleidcsextension_oci_tags {
    dynamic "defined_tags" {
      for_each = { for i, t in local.idc_defined_tag_list : "${t.namespace}.${t.key}" => t }
      content {
        namespace = defined_tags.value.namespace
        key       = defined_tags.value.key
        value     = defined_tags.value.value
      }
    }

    dynamic "freeform_tags" {
      for_each = { for t in local.idc_freeform_tag_list : t.key => t }
      content {
        key   = freeform_tags.value.key
        value = freeform_tags.value.value
      }
    }
  }
  lifecycle {
    ignore_changes = [
      schemas,
      urnietfparamsscimschemasoracleidcsextension_oci_tags
    ]
  }
}

resource "oci_identity_policy" "domain_cluster_policy" {
  provider       = oci.home-region
  count          = var.persistent_storage_access_model.access_style == "domain" ? 1 : 0
  compartment_id = var.persistent_storage.compartment_ocid
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${local.deployment_unique_name}-cluster-identity-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow any-user to manage object-family in compartment id ${var.persistent_storage.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}', target.bucket.name = /${var.persistent_storage.bucket_prefix}-bucket-*/}"
  ]
}

# Instance access Policies
# Skipped if create_identity_policies is false
resource "oci_identity_policy" "instance_policy" {
  provider       = oci.home-region
  count          = var.create_identity_policies ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to retrieve and manage resources related to the instances."
  name           = "${local.deployment_unique_name}-instance-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow any-user to read secret-bundles in compartment id ${var.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
    "Allow any-user to use secrets in compartment id ${var.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
    "Allow any-user to use instances in compartment id ${var.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
    "Allow any-user to manage object-family in compartment id ${var.persistent_storage.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }"
  ]
}

resource "oci_identity_policy" "subnet_policy" {
  provider       = oci.home-region
  count          = var.create_identity_policies ? 1 : 0
  compartment_id = data.oci_core_subnet.cluster_subnet.compartment_id
  description    = "The identity policy used by the ${local.deployment_unique_name} Qumulo cluster to manage resources related to the host subnet."
  name           = "${local.deployment_unique_name}-subnet-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow any-user to use virtual-network-family in compartment id ${data.oci_core_subnet.cluster_subnet.compartment_id} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
  ]
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

locals {
  access_key_id            = sensitive(var.persistent_storage_access_model.access_style == "explicit" ? var.persistent_storage_access_model.explicit_customer_secret_key_access_key : var.persistent_storage_access_model.access_style == "domain" ? oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0].access_key : oci_identity_customer_secret_key.classic_cluster_secret_key[0].id)
  secret_key               = sensitive(var.persistent_storage_access_model.access_style == "explicit" ? var.persistent_storage_access_model.explicit_customer_secret_key_secret_key : var.persistent_storage_access_model.access_style == "domain" ? oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0].secret_key : oci_identity_customer_secret_key.classic_cluster_secret_key[0].key)
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
  node_base_image   = var.node_base_image != null ? var.node_base_image : data.oci_core_images.latest.images[0].id
  cluster_policy_id = var.persistent_storage_access_model.access_style == "explicit" ? "1" : var.persistent_storage_access_model.access_style == "classic" ? oci_identity_policy.classic_cluster_policy[0].id : oci_identity_policy.domain_cluster_policy[0].id
}


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
    oci_identity_policy.instance_policy,
    local.cluster_policy_id
  ]
}

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
