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

resource "oci_core_volume" "permanent_disk" {
  count               = var.disk_count
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.deployment_unique_name}-${var.node_id + 1}-permanent-disk-${count.index + 1}"
  size_in_gbs         = var.size_in_gbs
  vpus_per_gb         = var.vpus_per_gb
  defined_tags        = length(var.defined_tags) > 0 ? var.defined_tags : null
  freeform_tags       = var.freeform_tags

  lifecycle {
    # Any disk property changes after the initial deployment are ignored
    ignore_changes = [availability_domain, compartment_id, size_in_gbs, vpus_per_gb]
  }
}

resource "oci_core_volume_attachment" "attach_permanent_disk" {
  count           = var.disk_count
  instance_id     = var.instance_id
  volume_id       = oci_core_volume.permanent_disk[count.index].id
  attachment_type = "paravirtualized"

  lifecycle {
    # Remapping disks post initial deployment is not allowed
    ignore_changes = [instance_id]
  }
}
