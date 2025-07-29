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

provider "oci" {
  tenancy_ocid        = var.tenancy_ocid
  region              = var.region
  user_ocid           = var.user_ocid
  auth                = var.oci_auth
  config_file_profile = var.oci_profile
  private_key         = var.oci_private_key
  private_key_path    = var.oci_private_key_path
  fingerprint         = var.oci_fingerprint
}

#
# Users should modify this state to reflect a remote backend as appropriate if
# they modify the persistent-storage directory and the provider backend
# settings therein
#
data "terraform_remote_state" "persistent_storage" {
  backend = "local"

  config = {
    path = "./persistent-storage/terraform.tfstate"
  }
}
