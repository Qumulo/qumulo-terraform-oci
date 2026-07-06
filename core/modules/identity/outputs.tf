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

output "classic_cluster_customer_secret_id" {
  value = var.persistent_storage_access_model.access_style == "classic" ? oci_identity_customer_secret_key.classic_cluster_secret_key[0].id : null
}

output "classic_cluster_customer_secret_key" {
  value = var.persistent_storage_access_model.access_style == "classic" ? oci_identity_customer_secret_key.classic_cluster_secret_key[0].key : null
}

output "domain_cluster_customer_secret_id" {
  value = var.persistent_storage_access_model.access_style == "domain" ? oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0].access_key : null
}

output "domain_cluster_customer_secret_key" {
  value = var.persistent_storage_access_model.access_style == "domain" ? oci_identity_domains_customer_secret_key.domain_cluster_secret_key[0].secret_key : null
}
