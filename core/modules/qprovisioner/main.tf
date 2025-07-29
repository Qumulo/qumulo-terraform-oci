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
  compartment_id = var.compartment_ocid
}

locals {
  availability_domain     = data.oci_identity_availability_domains.ads.availability_domains[0]["name"]
  ssh_public_key_contents = concat([for path in var.instance_ssh_public_key_paths : trimspace(file(path))], var.instance_ssh_public_key_strings)
}

data "oci_core_images" "base_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.instance_shape
  state                    = "AVAILABLE"
  sort_by                  = "DISPLAYNAME"
  sort_order               = "DESC"
}

resource "oci_core_instance" "provisioner" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain
  create_vnic_details {
    assign_ipv6ip             = "false"
    assign_private_dns_record = "true"
    assign_public_ip          = var.assign_public_ip
    subnet_id                 = var.subnet_ocid
    defined_tags              = length(var.defined_tags) > 0 ? var.defined_tags : null
    freeform_tags             = var.freeform_tags
  }
  display_name  = "${var.cluster_name}-provisioner"
  freeform_tags = var.freeform_tags
  defined_tags  = length(var.defined_tags) > 0 ? var.defined_tags : null

  metadata = {
    user_data = base64encode(templatefile(local.provision_script_path, {
      cluster_node_ip_addresses               = var.cluster_node_ip_addresses
      cluster_name                            = var.cluster_name
      clustering_node_ocid                    = var.clustering_node_ocid
      clustering_node_ip_address              = var.clustering_node_ip_address
      node_count                              = var.node_count
      permanent_disk_count                    = var.permanent_disk_count
      node_ip_addresses_and_fault_domains     = var.node_ip_addresses_and_fault_domains
      object_storage_uris                     = var.object_storage_uris
      soft_capacity_limit                     = var.soft_capacity_limit
      product_type                            = var.product_type
      admin_password                          = var.admin_password
      secret_ocid                             = var.secret_ocid
      floating_ip_addresses                   = var.floating_ip_addresses
      netmask                                 = var.netmask
      cluster_node_count_secret_id            = var.cluster_node_count_secret_id
      deployed_permanent_disk_count_secret_id = var.deployed_permanent_disk_count_secret_id
      cluster_soft_capacity_limit_secret_id   = var.cluster_soft_capacity_limit_secret_id
      dev_environment                         = var.dev_environment
    }))
    "ssh_authorized_keys" = join("\n", local.ssh_public_key_contents)
  }
  shape = var.instance_shape
  shape_config {
    ocpus = var.instance_ocpus
  }
  source_details {
    source_id               = data.oci_core_images.base_image.images[0].id
    source_type             = "image"
    boot_volume_vpus_per_gb = 20
  }
}

resource "null_resource" "wait_for_shutdown" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = templatefile(local.wait_for_shutdown_script_path, {
      instance_id = oci_core_instance.provisioner.id
    })
    quiet = true
  }

  triggers = {
    script_hash = "${sha256(oci_core_instance.provisioner.metadata.user_data)}"
  }

  depends_on = [oci_core_instance.provisioner]
}
