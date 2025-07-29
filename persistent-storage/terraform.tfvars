# ****************************** Required *************************************************************
# region                        - The OCI region in which to deploy the persistent storage
# compartment_ocid              - Ocid of the compartment in which to deploy the persistent storage
# persistent_storage_vault_ocid - Ocid of the vault in which we store the secrets for persistent storage.
# object_storage_bucket_count   - The number of object buckets to use for persistent storage. Default value is 16.

region                        = "my_region"
compartment_ocid              = "my_compartment"
persistent_storage_vault_ocid = "my_vault"
