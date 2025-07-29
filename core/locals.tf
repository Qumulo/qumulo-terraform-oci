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
  node_ips_and_fault_domains = length(module.qcluster.nodes) >= 5 || length(module.qcluster.nodes) == 3 ? join(" ", [for i in module.qcluster.nodes : "${i.private_ip},${i.fault_domain}"]) : join(" ", [for i in module.qcluster.nodes : "${i.private_ip},None"])
  object_storage_uris        = join(" ", var.persistent_storage.object_storage_uris)
  product_type               = var.q_cluster_cold ? "ARCHIVE_WITH_IA_STORAGE" : "ACTIVE_WITH_STANDARD_STORAGE"
}
