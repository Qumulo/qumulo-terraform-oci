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
  num_protection_domains = var.multi_ad_deployment == false ? length(local.fault_domains) : length(var.availability_domain_names)
}

output "nodes" {
  value = [
    for i, node in oci_core_instance.node : {
      name                = node.display_name
      private_ip          = node.private_ip
      id                  = node.id
      availability_domain = node.availability_domain
      fault_domain        = node.fault_domain
      protection_domain   = var.single_fault_domain == null ? (i % local.num_protection_domains) + 1 : null
    }
  ]
}

output "floating_ips" {
  value = join(",", sort([for i in local.all_node_ips : i.ip_address if !i.is_primary]))
}
