# ****************************** Required *************************************************************
# ***** Terraform Variables *****
# deployment_unique_name       - Unique name for the deployment. Takes the form of <cluster name>-<uuid from persistent storage deployment>
# tenancy_ocid                 - Ocid of the tenancy in which to deploy the identity resources
# compartment_ocid             - Ocid of the compartment in which to deploy the identity resources
# subnect_ocid                 - Ocid of the compartment containing the subnet where the cluster will be deployed
# persistent_storage_access_model - Configuration settings for cluster access to the persistent object storage
#   access_style - One of: classic, explicit, domain
#   explicit_customer_secret_key_access_key - Required when access_style = "explicit"
#   explicit_customer_secret_key_secret_key - Required when access_style = "explicit"
#   domain_idcs_endpoint - Required when access_style = "domain"
#   domain_identity_domain_display_name - Required when access_style = "domain"


deployment_unique_name = ""

tenancy_ocid                        = ""
compartment_ocid                    = ""
subnet_compartment_ocid             = ""
persistent_storage_compartment_ocid = ""
persistent_storage_bucket_prefix    = ""

persistent_storage_access_model = {
  access_style = "classic"
}


