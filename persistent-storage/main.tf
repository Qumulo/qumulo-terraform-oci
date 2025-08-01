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

resource "random_uuid" "deployment_id" {
}

resource "null_resource" "name_lock" {
  triggers = {
    deployment_unique_name = "persistent-storage-${random_uuid.deployment_id.result}"
  }

  lifecycle { ignore_changes = all }
}

resource "null_resource" "region_lock" {
  triggers = {
    deployment_region = var.region
  }

  lifecycle { ignore_changes = all }
}

resource "null_resource" "vault_lock" {
  triggers = {
    deployment_vault_ocid = var.persistent_storage_vault_ocid
  }

  lifecycle { ignore_changes = all }
}

data "oci_kms_vault" "deployment_vault" {
  vault_id = null_resource.vault_lock.triggers.deployment_vault_ocid
}

data "oci_objectstorage_namespace" "namespace" {
  compartment_id = var.compartment_ocid
}

resource "oci_kms_key" "vault_key" {
  count          = var.vault_key_ocid == null ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${local.deployment_unique_name}-vault-key"
  key_shape {
    algorithm = "AES"
    length    = 32
  }
  management_endpoint = local.deployment_vault.management_endpoint
  freeform_tags       = var.freeform_tags
  defined_tags        = length(var.defined_tags) > 0 ? var.defined_tags : null
}

locals {
  deployment_unique_name   = null_resource.name_lock.triggers.deployment_unique_name
  deployment_region        = null_resource.region_lock.triggers.deployment_region
  deployment_vault         = data.oci_kms_vault.deployment_vault
  retrieve_stored_value_sh = ["${path.module}/scripts/retrieve_stored_value.sh"]
  update_stored_value_sh   = "${path.module}/scripts/update_stored_value.sh"
  vault_key_ocid           = var.vault_key_ocid != null ? var.vault_key_ocid : oci_kms_key.vault_key[0].id
  namespace                = data.oci_objectstorage_namespace.namespace.namespace
}

resource "oci_vault_secret" "bucket_count" {
  compartment_id = var.compartment_ocid
  key_id         = local.vault_key_ocid
  secret_name    = "${local.deployment_unique_name}-bucket-count"
  vault_id       = local.deployment_vault.id
  freeform_tags  = var.freeform_tags
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null

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

data "external" "bucket_count" {
  program = concat(local.retrieve_stored_value_sh, [oci_vault_secret.bucket_count.id])
}

resource "oci_objectstorage_bucket" "bucket" {
  count          = var.object_storage_bucket_count
  compartment_id = var.compartment_ocid
  name           = "${local.deployment_unique_name}-bucket-${count.index + 1}"
  namespace      = local.namespace
  freeform_tags  = var.freeform_tags
  defined_tags   = length(var.defined_tags) > 0 ? var.defined_tags : null

  provisioner "local-exec" {
    when    = destroy
    command = "oci os object bulk-delete --namespace-name ${self.namespace} --bucket-name ${self.name} --force"
  }

  lifecycle {
    ignore_changes = [compartment_id, name, namespace]

    precondition {
      condition = tonumber(data.external.bucket_count.result.value) <= var.object_storage_bucket_count
      error_message = "Lowering the number of object storage buckets is not supported."
    }
  }
}

resource "null_resource" "deployed_bucket_count" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = templatefile(local.update_stored_value_sh, {
      secret_id    = oci_vault_secret.bucket_count.id
      base64_value = base64encode(length(resource.oci_objectstorage_bucket.bucket))
    })
    quiet = true
  }

  triggers = {
    deployed_bucket_count = length(resource.oci_objectstorage_bucket.bucket)
  }
}
