# Qumulo Cluster on OCI Terraform Module

This Terraform module deploys a Qumulo cluster on Oracle Cloud Infrastructure (OCI). It provides a scalable and highly available file storage solution with enterprise-grade features.

## Architecture

The deployment creates the following components:
- Qumulo cluster nodes across multiple fault domains
- Network security groups and rules
- Required IAM policies and groups

## Prerequisites

1. A Linux machine running Terraform version 1.12.2 or later
   * OCI CLI and "jq" installed

2. You will need the following assets provided by Qumulo:
   * qumulo-core.rpm (version 7.4.3B or later)

3. OCI Object Storage User Permissions

   This account is used by the cluster nodes to gain access to the Object Storage buckets used for persistent storage:
   
   One of the following options must be satisfied to proceed:
     
   A. Allow the Stack to deploy the necessary Identity resources automatically

      The OCI account deploying the cluster must have the following permissions:

      * manage users in either the TENANCY or the selected Identity Domain
      * manage groups in either the TENANCY or the selected Identity Domain
      * manage policies in either the TENANCY or the selected Identity Domain

      This method will create the necessary identity resources in either the default identity domain or a user selected identity domain based on the settings in the `persistent_storage_access` object
      1. To create the identity resources in the default identity domain
         * set `access_style` to `classic`
      2. To create the identity resources in a non-default identity domain
         * set `access_style` to `domain`
         * set `domain_idcs_endpoint` to the URL of the endpoint of the desired Identity Domain
         * set `domain_identity_domain_display_name` to the display name of the desired Identity Domain

      B. Use a precreated User, Group, and Identity Policy
      * Create a new User
      * Create a Customer Secret Key for this user, retain the Access Key and Secret Key values for use below
      * Create a Group that includes this user
      * Create an Identity Policy that includes the statement:
      ```
          "Allow group <group created above> to manage object-family in compartment id <cluster deployment compartment> where target.bucket.name = <bucket-prefix in output from persistent storage terraform stack>-bucket-*/"
      ```
      * set the following variables in the `persistent_storage_access_model` object:
        * set `access_style` to `explicit`
        * set `explicit_customer_secret_key_access_key` to the value of the Customer Secret Key's Access ID (not the OCID)
        * set `explicit_customer_secret_key_secret_key` to the value of the Customer Secret Key's Secret

4. OCI Cluster User Permissions:

   These permissions allow the cluster nodes and provisioner node tha ability to interact with resources necessary for cluster operations.

   * One of the following options must be satisfied to proceed: 

       A. Deploying user has the following permissions:
      * manage dynamic groups IN TENANCY
      * manage policies in TENANCY

      B: Precreated Dynamic Group and Identity Policy
      * Create a Dynamic Group that includes all compute instances in deployment compartment
      * Create an Identity Policy that includes the following permissions, this policy must be created in a Compartment that contains both the Compartment where the cluster resources will be deployed and the Compartment were the target Subnet is deployed.
         ```
         "Allow dynamic-group <dynamic group name> to read secret-bundles in compartment id <deployment compartment ocid>"
         "Allow dynamic-group <dynamic group name> to use secrets in compartment id <deployment compartment ocid>"
         "Allow dynamic-group <dynamic group name> to manage virtual-network-family in compartment id <network compartment ocid>"
         "Allow dynamic-group <dynamic group name> to use instances in compartment id <deployment compartment ocid>" 
         ```
      * Set variable `create_dynamic_group_and_identity_policy` to `false` in the `terraform.tfvars` file

5. OCI Configuration:
   * Valid OCI credentials set for the DEFAULT profile
   * The region in your profile should match the region of the deployment
   * See [OCI CLI Configuration Guide](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsconfigureocicli.htm)

6. Network Requirements:
   * Subnet with outbound internet access for dependencies and Qumulo monitoring
   * Access to KMS vault for cluster deployment

## Creating an Initial Cluster

### 1. Deploy Persistent Storage
The persistent storage of the Qumulo cluster is segregated under a subdirectory `persistent-storage` to give you flexibility to scale compute resources without destroying the
persistent storage. The output of the persistent storage deployment will be automatically passed to the compute resource deployment in the next step.

```bash
cd persistent-storage
```

Edit `terraform.tfvars` to set your environment-specific configurations:
```hcl
# Example configuration
region = "us-phoenix-1"
compartment_ocid = "ocid.xyz"
```

```bash
terraform init
terraform plan
terraform apply
```

Alternatively, you can set up all the terraform variables in `terraform.tfvars` under the parent directory and run `terraform plan/apply -var-file=../terraform.tfvars`

### 2. Deploy Compute Resources
Warning: please make sure that the persistent storage used in this step was freshly deployed. Re-using persistent storage that was associated with any previous
compute resources is not supported.

```bash
cd ../
```

Edit `terraform.tfvars` to set your environment-specific configurations:
```hcl
# Example configuration
compartment_id       = "ocid1.compartment.oc1..example"
q_cluster_name       = "qumulo-cluster"
q_node_count         = 3
q_cluster_node_count = 3
```

```bash
terraform init
terraform plan
terraform apply
```

Deployment typically takes 10-20 minutes to complete.

## Node Add
One of Qumulo's advantages is that compute resources can be scaled independently of the storage capacity. If your workload demands additional compute nodes,
you can simply add them to your cluster. If they are no longer needed, you can later remove them.

Edit `terraform.tfvars` to set the target number of nodes:
```hcl
# Example configuration, previously those numbers were both 3
q_node_count         = 5
q_cluster_node_count = 5
```

```bash
terraform plan
terraform apply
```

Node add typically takes 10-20 minutes to complete.

## Node Remove
Node remove needs to happen in 2 steps in order to make sure that all filesystem dependencies are cleaned up before the actual node resources are torn down.

### 1. Remove Nodes From the Cluster Membership
Edit `terraform.tfvars` to reduce the number of nodes in the cluster:
```hcl
# Example configuration, previously those numbers were both 5
q_node_count         = 5
q_cluster_node_count = 3
```

```bash
terraform plan
terraform apply
```

Removing nodes from the cluster typically takes 5-10 minutes to complete.

### 2. Tear Down the Unused Node Resources
Edit `terraform.tfvars` to reduce the number of nodes deployed:
```hcl
# Example configuration
q_node_count         = 3
q_cluster_node_count = 3
```

```bash
terraform plan
terraform apply
```

Tearing down node resources typically takes less than 5 minutes to complete.

## Adding Object Storage Buckets
The maximum soft capacity limit on the cluster is determined by the number of object storage buckets configured on the backend. Each object storage bucket
supports up to 500TB capacity. If more capacity beyond the current maximum soft capacity limit is needed, you need to add object storage buckets first.

This is a two-step operation.

### 1. Deploy Additional Bucket Resources
```bash
cd persistent-storage
```

Edit `terraform.tfvars` to increase the number of buckets:
```hcl
# Example configuration
object_storage_bucket_count = 20
```

```bash
terraform plan
terraform apply
```
Now you have deployed additional buckets but they are not configured to be used by the cluster yet. Let's do that next.

### 2. Configure the Cluster to Utilize the New Buckets
```bash
cd ../
```

Optionally, you can increase the cluster soft capacity limit at the same time. The maximum cluster soft capacity limit is 500TB per object storage bucket.
```hcl
# Example configuration
q_cluster_soft_capacity_limit = 1500
```

```bash
terraform plan
terraform apply
```

The new buckets will be picked up by the provisioning logic automatically. Reconfiguration typically takes less than 5 minutes.

## State Management

The Terraform state is stored locally by default. For production deployments, consider:
- Using OCI Object Storage for remote state
- Implementing state locking
- Regular state backups

## Supported Operations

- Initial cluster deployment
- Node add/remove post initial cluster deployment
- Adding additional object storage buckets post initial cluster deployment
- Increasing cluster soft capacity limit
- Changing floating IPs on QFSD versions >= 7.5.1

### Limitations
- 4 node clusters with fault domain tolerence are not supported. We recommend an initial cluster of 3 nodes or 5 or more nodes for fault domain tolerence.
- Changing a cluster of 3 nodes or 5 or more nodes to 4 nodes is not supported due to fault domain tolerence incompatibility, vice versa.
- The maximum cluster soft capacity limit is 500TB per object storage bucket.

## Using customer managed keys for encryption at rest
This scripts supports the use of customer managed keys for encrypting the object storage buckets and the block volumes attached to cluster and provisioner instances at rest.  Customer managed keys must be registered as Master Encryption Keys in the same region as the cluster deployment.  The process for deploying customer managed keys is as follows.

### Customer managed key for persistent object storage
- Create or import a Master Encryption Key in the same region as the deployed cluster
- Create a policy statement that allows the object storage service to access the key (e.g. `Allow service objectstorage-us-phoenix-1 to use keys in compartment Storage`)
  - This policy can be made stricter through the use of conditions, but must allow the object storage service to access the selected encryption key
- Set the variable `object_storage_encryption_key` to the OCID of the desired key before applying the `persistent-storage` stack.
- This variable can be changed and the stack re-applied without redeploying the persistent storage buckets.  This allows key rotation on an existing cluster's persistent object storage.

### Customer managed key for instance block volumes
- Create or import a Master Encryption Key in the same region as the deployed cluster
- Create a policy statement that allows the object storage service to access the key (e.g. `Allow service blockstorage to use keys in compartment Storage`)
  - This policy can be made stricter through the use of conditions, but must allow the block storage service to access the selected encryption key
- Set the variable `block_volume_encryption_key` to the OCID of the desired key before applying the main stack.
- Changing the Block Volume encryption keys after deployment is not supported.


## Deploying outside the Home Region
To deploy a cluster outside the home region, the follwing requrements must be satisfied:
- The Secrets Vaults for the cluster and persistent storage must be in the same region as the cluster.
- Update the region for the DEFAULT profile in your `~/.oci/config` file to the region the cluster will be deployed.
- Add the variable `home_region` to the top level `terraform.tfvars` file and set it to the home region of the deployment tenancy.
- Because of extended IAM replication times between regions, consider increasing the values of `object_storage_access_delay` and `provisioner_wait_for_completion_max_retries`, especially when using a non-default identity domain.

## Upgrading from previous versions of this Terraform
When upgrading from release 2.4.0 or earlier, the following changes must be made to prevent cluster redeployment
- Do not set customer defined encryption keys for block volumes, setting customer defined keys for persistent storage buckets is supported
- If using the `custom_secret_key_id` and `custom_secret_key` variables, add the `persistent_storage_access_model` block and make the following changes
  - set `access_style` to `explicit`
  - set `explicit_customer_secret_key_access_key` to the value of `custom_secret_key_id`
  - set `explicit_customer_secret_key_secret_key` to the value of `custom_secret_key`
- Otherwise, add the `persistent_storage_access_model` block and set `access_style` to `classic`
- Apply the terraform stack to update the resource identities associated with persistent storage access.  There should be no changes to the deployed cluster resources.

## Support

For issues beyond the scope of this module:
- Contact Qumulo support
- Consult OCI documentation
- Review Terraform logs

## License

See [LICENSE](LICENSE) file for details.
