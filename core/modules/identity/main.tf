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


# Classic access model Resources
resource "oci_identity_user" "classic_cluster_user" {
  provider       = oci.home-region
  count          = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "${var.deployment_unique_name}-user"
  description    = "The user used by the ${var.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  email          = var.cluster_email
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_customer_secret_key" "classic_cluster_secret_key" {
  provider     = oci.home-region
  count        = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  user_id      = oci_identity_user.classic_cluster_user[0].id
  display_name = "${var.deployment_unique_name}-secret-key"
}

resource "oci_identity_group" "classic_cluster_identity_group" {
  provider       = oci.home-region
  count          = var.persistent_storage_access_model.access_style == "classic" ? 1 : 0
  compartment_id = var.tenancy_ocid
  description    = "The identity group used by the ${var.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${var.deployment_unique_name}-identity-group"
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
  description    = "The identity policy used by the ${var.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${var.deployment_unique_name}-cluster-identity-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow group ${oci_identity_group.classic_cluster_identity_group[0].name} to manage object-family in compartment id ${var.persistent_storage_compartment_ocid} where target.bucket.name = /${var.persistent_storage_bucket_prefix}-bucket-*/"
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
  user_name     = "${var.deployment_unique_name}-user"
  description   = "The user used by the ${var.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  user_type     = "Service"
  name {
    given_name  = var.deployment_unique_name
    family_name = "qumulo"
  }
  emails {
    value   = var.cluster_email
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
  display_name  = "${var.deployment_unique_name}-secret-key"
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
  display_name  = "${var.deployment_unique_name}-domain-identity-group"

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
  compartment_id = var.persistent_storage_compartment_ocid
  description    = "The identity policy used by the ${var.deployment_unique_name} Qumulo cluster to authenticate to object storage buckets."
  name           = "${var.deployment_unique_name}-cluster-identity-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow group '${var.persistent_storage_access_model.domain_identity_domain_display_name}'/'${oci_identity_domains_group.domain_cluster_identity_group[0].display_name}' to manage object-family in compartment id ${var.persistent_storage_compartment_ocid} where target.bucket.name = /${var.persistent_storage_bucket_prefix}-bucket-*/"

  ]
}

# Instance access Policies
resource "oci_identity_policy" "instance_policy" {
  provider       = oci.home-region
  compartment_id = var.compartment_ocid
  description    = "The identity policy used by the ${var.deployment_unique_name} Qumulo cluster to retrieve and manage resources related to the instances."
  name           = "${var.deployment_unique_name}-instance-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow any-user to read secret-bundles in compartment id ${var.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
    "Allow any-user to use secrets in compartment id ${var.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
    "Allow any-user to use instances in compartment id ${var.compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
    "Allow any-user to manage object-family in compartment id ${var.persistent_storage_compartment_ocid} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}', target.bucket.name = /${var.persistent_storage_bucket_prefix}-bucket-*/ }"
  ]
}

resource "oci_identity_policy" "subnet_policy" {
  provider       = oci.home-region
  compartment_id = var.subnet_compartment_id
  description    = "The identity policy used by the ${var.deployment_unique_name} Qumulo cluster to manage resources related to the host subnet."
  name           = "${var.deployment_unique_name}-subnet-policy"
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags  = var.freeform_tags

  statements = [
    "Allow any-user to use virtual-network-family in compartment id ${var.subnet_compartment_id} where all { request.principal.type = 'instance', request.principal.compartment.id = '${var.compartment_ocid}' }",
  ]
}
