# ****************************** Required *************************************************************
# ***** Terraform Variables *****
# region                       - The OCI region in which to deploy the Qumulo cluster
# availability_domain          - The availability domain in which to deploy the Qumulo cluster. Leave it at null to use the default availability domain.
# tenancy_ocid                 - Ocid of the tenancy in which to deploy the Qumulo cluster
# compartment_ocid             - Ocid of the compartment in which to deploy the Qumulo cluster
# subnect_ocid                 - Ocid of the subnet in which to deploy the Qumulo cluster
# user_ocid                    - Ocid of the user that runs this script
# q_cluster_name               - Name must be an alpha-numeric string between 2 and 15 characters. Dash (-) is allowed if not the first or last character. Must be unique per cluster.
# q_cluster_admin_password     - Minumum 8 characters and must include one each of: uppercase, lowercase, and a special character.  If replacing a cluster make sure this password matches current running cluster.
# node_ssh_public_key_paths    - List of paths to the pre-created admin public key files that should be installed on the OCI virtual machines running Qumulo
# node_ssh_public_key_strings  - List of pre-created admin public keys that should be installed on the OCI virtual machines running Qumulo
#  node_ssh_public_key_paths and node_ssh_public_key_strings can be used together or separately, but at least one must be set.

region                      = "my_region"
availability_domain         = null
tenancy_ocid                = "my_tenancy"
compartment_ocid            = "my_compartment"
subnet_ocid                 = "my_subnet"
user_ocid                   = "my_ocid"
q_cluster_name              = "my_cluster"
q_cluster_admin_password    = "my_password"
node_ssh_public_key_paths   = ["my_public_key_file_path", ]
node_ssh_public_key_strings = ["my_public_key_string", ]

# Set exactly one of the following variables:
# qumulo_core_rpm_path      - Local path to the downloaded qumulo-qcore.rpm file.
# qumulo_core_rpm_url       - URL to object storing a qumulo-qcore.rpm file

qumulo_core_rpm_path = "my_rpm_path"
qumulo_core_rpm_url  = null

#
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
node_instance_shape           = "VM.DenseIO.E4.Flex"
node_instance_ocpus           = 8
block_volume_count            = 3
q_cluster_cold                = false
vault_ocid                    = "my_vault"
persistent_storage_vault_ocid = "my_vault"
custom_secret_key_id          = null
custom_secret_key             = null
q_cluster_floating_ips        = 0
