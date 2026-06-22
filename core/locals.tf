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

locals {
  # If a number of permanent disks is not given, base it on the instance CPU count instead. It cannot go lower than 3.
  permanent_disk_count       = var.block_volume_count == null ? max(3, var.node_instance_ocpus / 2) : var.block_volume_count
  cluster_node_ips           = join(" ", [for i in module.qcluster.nodes : i.private_ip])
  clustering_node_id         = module.qcluster.nodes[0].id
  clustering_node_ip         = module.qcluster.nodes[0].private_ip
  node_ips_and_fault_domains = var.single_fault_domain == null && (length(module.qcluster.nodes) >= 5 || length(module.qcluster.nodes) == 3) ? join(" ", [for i in module.qcluster.nodes : "${i.private_ip},${i.protection_domain}"]) : join(" ", [for i in module.qcluster.nodes : "${i.private_ip},None"])
  object_storage_uris        = join(" ", var.persistent_storage.object_storage_uris)
  product_type               = var.q_cluster_cold ? "ARCHIVE_WITH_IA_STORAGE" : "ACTIVE_WITH_STANDARD_STORAGE"

  availability_domain_names = [for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name]
}

locals {
  vault = data.oci_kms_vault.deployment_vault
}

locals {
  cluster_email          = "${local.deployment_unique_name}-user@qumulo.com"
  deployment_unique_name = null_resource.name_lock.triggers.deployment_unique_name
}

locals {
  access_key_id            = sensitive(var.persistent_storage_access_model.access_style == "explicit" ? var.persistent_storage_access_model.explicit_customer_secret_key_access_key : var.persistent_storage_access_model.access_style == "domain" ? oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0].access_key : oci_identity_customer_secret_key.classic_cluster_secret_key[0].id)
  secret_key               = sensitive(var.persistent_storage_access_model.access_style == "explicit" ? var.persistent_storage_access_model.explicit_customer_secret_key_secret_key : var.persistent_storage_access_model.access_style == "domain" ? oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0].secret_key : oci_identity_customer_secret_key.classic_cluster_secret_key[0].key)
  retrieve_stored_value_sh = ["${path.module}/scripts/retrieve_stored_value.sh"]
  vault_key_ocid           = var.vault_key_ocid != null ? var.vault_key_ocid : oci_kms_key.vault_key[0].id
}

locals {
  node_base_image   = var.node_base_image != null ? var.node_base_image : data.oci_core_images.latest.images[0].id
  cluster_policy_id = var.persistent_storage_access_model.access_style == "explicit" ? "1" : var.persistent_storage_access_model.access_style == "classic" ? oci_identity_policy.classic_cluster_policy[0].id : oci_identity_policy.domain_cluster_policy[0].id
}

