# ****************************** Required *************************************************************
# ***** Terraform Variables *****
# region                       - The OCI region in which to deploy the Qumulo cluster
# multi_ad_deployment         - If true, spread nodes across availability domains; otherwise spread across fault domains in the first availability domain.
# availability_domain          - The availability domain in which to deploy the Qumulo cluster. Leave it at null to use the default availability domain.
# tenancy_ocid                 - Ocid of the tenancy in which to deploy the Qumulo cluster
# compartment_ocid             - Ocid of the compartment in which to deploy the Qumulo cluster
# subnect_ocid                 - Ocid of the subnet in which to deploy the Qumulo cluster
# user_ocid                    - Ocid of the user that runs this script
# q_cluster_name               - Name must be an alpha-numeric string between 2 and 15 characters. Dash (-) is allowed if not the first or last character. Must be unique per cluster.
# q_cluster_admin_password     - Minumum 8 characters and must include one each of: uppercase, lowercase, and a special character.  If replacing a cluster make sure this password matches current running cluster.
# node_ssh_public_key_paths    - List of paths to the pre-created admin public key files that should be installed on the OCI virtual machines running Qumulo
# node_ssh_public_key_strings  - List of pre-created admin public keys that should be installed on the OCI virtual machines running Qumulo
# node_ssh_public_key_paths and node_ssh_public_key_strings can be used together or separately, but at least one must be set.
# qumulo_core_rpm_url          - URL to object storing a qumulo-qcore.rpm file

dev_environment     = true
multi_ad_deployment = false
availability_domain = null
tenancy_ocid        = "ocid1.tenancy.oc1..aaaaaaaaldhfsc22udvuq45bjlboit7qtgeampm5rll4rlsxgphvokmvrz3q"
compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaah73bo7rudv54umzez5ylvyx2fmcexpabcujam4wo4hr75q7nkdkq"
persistent_storage_access_model = {
  access_style = "domain"
  #  explicit_customer_secret_key_access_key = "<key>"
  #  explicit_customer_secret_key_secret_key = "<key>"
  domain_idcs_endpoint                = "https://idcs-d08cd840959c4dfb917915e78b2f56d1.identity.oraclecloud.com:443"
  domain_identity_domain_display_name = "cnq-test"
}
user_ocid                = "ocid1.user.oc1..aaaaaaaa3sy5p5qlei27gfxyousxr7njne52as66shsivniwd5j2t5n7vpaa"
q_cluster_name           = "cmk-testing"
q_cluster_admin_password = "P@ssword1!"
# node_ssh_public_key_paths   = ["my_public_key_file_path", ]
node_ssh_public_key_strings = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7MWle4ks7Sfp42u4rqLtmWrogRyR/QVcTCs+I74Jo8 rjones@rjones-Standard-PC-i440FX-PIIX-1996", ]
qumulo_core_rpm_url         = "https://objectstorage.us-sanjose-1.oraclecloud.com/p/osmdFCTq2iSIURcfhmHmn3VpncCtJ1-i_M0ZMRND0iX9zGg0SzjvD3oyn3xux4sx/n/axdm2btt1ij3/b/qumulo-core-packages/o/qumulo-core-7.8.4.1.rpm"

## us-sanjose-1
#region              = "us-sanjose-1"
#subnet_ocid              = "ocid1.subnet.oc1.us-sanjose-1.aaaaaaaa7yvqpbsyt7r3psy73c4krtznnpeijjh3oehwy2bgq7zt54ac75zq"
#node_base_image               = "ocid1.image.oc1.us-sanjose-1.aaaaaaaanw2bf7ooznnzheswk6knsvvo66lf3qox6ulsvatvvorc57pumqwa"
#vault_ocid                    = "ocid1.vault.oc1.us-sanjose-1.grt6vyptaaeja.abzwuljrosvktnzygvjos7nqn3slvcsxvqaghwjb76ef7ohnuhfdshmmlita"
#persistent_storage_vault_ocid = "ocid1.vault.oc1.us-sanjose-1.grt6vyptaaeja.abzwuljrosvktnzygvjos7nqn3slvcsxvqaghwjb76ef7ohnuhfdshmmlita"

## us-phoenix-1
region                        = "us-phoenix-1"
home_region                   = "us-sanjose-1"
subnet_ocid                   = "ocid1.subnet.oc1.phx.aaaaaaaad7guhxw4vlgxkztursud4kxhwbucxcwdz7g2fdutajqebyj4dmhq"
node_base_image               = "ocid1.image.oc1.phx.aaaaaaaaww5vwcj2ycheg6zk7b2fxbay7pyqdb3ab6g3pslyxrslb7celdlq"
vault_ocid                    = "ocid1.vault.oc1.phx.efvcwh34aaen6.abyhqljt55xv64t6btzey4xr2qmas4pe7mba2catu7ux5qpecs4ghuocp3zq"
persistent_storage_vault_ocid = "ocid1.vault.oc1.phx.efvcwh34aaen6.abyhqljt55xv64t6btzey4xr2qmas4pe7mba2catu7ux5qpecs4ghuocp3zq"

object_storage_access_delay = 450
provisioner_wait_for_completion_max_retries = 90

# ****************************** Advanced Configurations **********************************************
# q_node_count                  - The number of nodes to deploy, this number can be higher than q_cluster_node_count if not all deployed nodes are meant to be added to the cluster.
# q_cluster_node_count          - The number of nodes in the Qumulo cluster membership
# q_cluster_soft_capacity_limit - The maximum soft capacity of your Qumulo cluster, in TB
# node_instance_shape           - The vm shape for the Qumulo nodes
# node_instance_ocpus           - The number of ocpus on each Qumulo node
# block_volume_count            - The number of disks used as write cache and dkv per Qumulo node
# q_cluster_cold                - If true, creates a cold cluster, which tiers long-lived data to the infrequent access object storage tier.
# vault_ocid                    - Ocid of the vault in which we store the secret key and access key for object storage access.
# persistent_storage_vault_ocid - Ocid of the vault in which we store the secrets for persistent storage.
# custom_secret_key_id          - The secret key id of a user with full object storage access in the cluster's compartment. Leave it at null to create a new user and secret key for this purpose.
# custom_secret_key             - The secret key of a user with full object storage access in the cluster's compartment. Leave it at null to create a new user and secret key for this purpose.
# q_cluster_floating_ips        - The number of floating ips associated with the cluster.

q_node_count                  = 3
q_cluster_node_count          = 3
q_cluster_soft_capacity_limit = 500
node_instance_shape           = "VM.Standard.E5.Flex"
node_instance_ocpus           = 8
block_volume_count            = 3
q_cluster_cold                = false
q_cluster_floating_ips        = 4
assign_public_ip              = true

