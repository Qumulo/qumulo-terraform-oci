# ****************************** Required *************************************************************
# region                        - The OCI region in which to deploy the persistent storage
# compartment_ocid              - Ocid of the compartment in which to deploy the persistent storage
# persistent_storage_vault_ocid - Ocid of the vault in which we store the secrets for persistent storage.
# object_storage_bucket_count   - The number of object buckets to use for persistent storage. Default value is 16.

region           = "us-phoenix-1"
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaah73bo7rudv54umzez5ylvyx2fmcexpabcujam4wo4hr75q7nkdkq"
## us-sanjose-1
#persistent_storage_vault_ocid = "ocid1.vault.oc1.us-sanjose-1.grt6vyptaaeja.abzwuljrosvktnzygvjos7nqn3slvcsxvqaghwjb76ef7ohnuhfdshmmlita"
#object_storage_encryption_key = "ocid1.key.oc1.us-sanjose-1.grt6vyptaaeja.abzwuljrm52itxjdupxjgbllkgcvy6db3r4bsrlm5ho374e5csdprq6yvbmq"

## us-phoenix-1
persistent_storage_vault_ocid = "ocid1.vault.oc1.phx.efvcwh34aaen6.abyhqljt55xv64t6btzey4xr2qmas4pe7mba2catu7ux5qpecs4ghuocp3zq"
#object_storage_encryption_key = "ocid1.key.oc1.phx.efu47625aaf3k.abyhqljtncyaaywwrkdvgxhy2bzfoj6gzr5ucbjuc23h6jwlcih3jqepk3sq"

object_storage_bucket_count = 4