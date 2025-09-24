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

data "oci_identity_availability_domains" "ads" {
  count          = var.availability_domain == null ? 1 : 0
  compartment_id = var.compartment_ocid
}

data "oci_identity_fault_domains" "fault_domains" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
}

locals {
  availability_domain = var.availability_domain == null ? data.oci_identity_availability_domains.ads[0].availability_domains[0]["name"] : var.availability_domain
  fault_domains       = data.oci_identity_fault_domains.fault_domains.fault_domains
}

resource "oci_core_instance" "node" {
  count               = var.node_count
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain
  fault_domain        = local.fault_domains[count.index % length(local.fault_domains)].name
  create_vnic_details {
    assign_ipv6ip             = "false"
    assign_private_dns_record = "true"
    assign_public_ip          = var.assign_public_ip
    subnet_id                 = var.subnet_ocid
    defined_tags              = length(var.defined_tags) > 0 ? var.defined_tags : null
    freeform_tags             = var.freeform_tags
  }
  display_name  = "${var.deployment_unique_name}-node-${count.index + 1}"
  defined_tags  = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags = var.freeform_tags

  metadata = {
    user_data = base64encode(templatefile(local.provision_script_path, {
      qumulo_core_uri             = var.qumulo_core_object_uri
      object_storage_uris         = var.object_storage_uris
      access_key_id               = var.access_key_id
      secret_key                  = var.secret_key
      object_storage_access_delay = var.object_storage_access_delay
    }))
    "ssh_authorized_keys" = join("\n", local.ssh_public_key_contents)
  }
  shape = var.node_instance_shape
  shape_config {
    ocpus = var.node_instance_ocpus
  }
  source_details {
    source_id               = var.node_base_image
    source_type             = "image"
    boot_volume_size_in_gbs = 256
    boot_volume_vpus_per_gb = 30
  }

  lifecycle {
    ignore_changes = [metadata, availability_domain, fault_domain, source_details]

    precondition {
      condition     = var.persisted_node_count <= var.node_count
      error_message = "Lowering the number of deployed nodes (q_node_count) is only supported after removing the extra nodes from the cluster membership via q_cluster_node_count."
    }
  }
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }
}

data "oci_core_vnic_attachments" "attachments" {
  count               = length(oci_core_instance.node)
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain
  instance_id         = oci_core_instance.node[count.index].id
}

locals {
  vnic_ids = [for element in data.oci_core_vnic_attachments.attachments : element.vnic_attachments[0]["vnic_id"]]
}

resource "oci_core_private_ip" "private_ip" {
  count         = var.floating_ip_count
  vnic_id       = local.vnic_ids[floor(count.index / 63)]
  freeform_tags = var.freeform_tags
  lifecycle {
    ignore_changes = [vnic_id]
  }
}

data "oci_core_private_ips" "private_ip_source" {
  count      = length(oci_core_instance.node)
  depends_on = [oci_core_private_ip.private_ip]
  vnic_id    = local.vnic_ids[count.index]
}

locals {
  all_node_ips            = flatten([for source in data.oci_core_private_ips.private_ip_source : [for ip in source.private_ips : ip]])
  ssh_public_key_contents = concat([for path in var.node_ssh_public_key_paths : trimspace(file(path))], var.node_ssh_public_key_strings)
}

module "disk" {
  count  = var.node_count
  source = "../qcluster-disk"

  availability_domain    = local.availability_domain
  compartment_ocid       = var.compartment_ocid
  deployment_unique_name = var.deployment_unique_name
  instance_id            = oci_core_instance.node[count.index].id
  node_id                = count.index
  disk_count             = var.permanent_disk_count
  persisted_disk_count   = var.persisted_disk_count
  size_in_gbs            = "270"
  vpus_per_gb            = "10"
  defined_tags           = var.defined_tags
  freeform_tags          = var.freeform_tags
}
