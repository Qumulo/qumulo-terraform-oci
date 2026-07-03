/*
 * MIT License
 *
 * Copyright (c) 2026 Qumulo
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

module "identity" {
  source = "../core/modules/identity"

  providers = {
    oci             = oci
    oci.home-region = oci.home-region
  }

  deployment_unique_name              = var.deployment_unique_name
  cluster_email                       = local.cluster_email
  tenancy_ocid                        = var.tenancy_ocid
  compartment_ocid                    = var.compartment_ocid
  persistent_storage_access_model     = var.persistent_storage_access_model
  subnet_compartment_id               = var.subnet_compartment_ocid
  persistent_storage_compartment_ocid = var.persistent_storage_compartment_ocid
  persistent_storage_bucket_prefix    = var.persistent_storage_bucket_prefix
  defined_tags                        = var.defined_tags
  freeform_tags                       = var.freeform_tags
}
