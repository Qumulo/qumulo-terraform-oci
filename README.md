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

3. OCI User Permissions:
   * manage all-resources in compartment your-qumulo-compartment

   * One of: 

       A. OCI Tenancy User Permissions:
      * manage users IN TENANCY
      * manage groups IN TENANCY
      * manage dynamic-groups IN TENANCY

      B: Precreated Dynamic Group and Identity Policy
      * Dynamic Group must include all compute instances in deployment compartment
      * Identity Policy must include following permissions
         ```
         "Allow dynamic-group \<dynamic group name> to read secret-bundles in compartment id \<deployment compartment ocid>"
         "Allow dynamic-group \<dynamic group name> to use secrets in compartment id \<deployment compartment ocid>"
         "Allow dynamic-group \<dynamic group name> to manage virtual-network-family in compartment id \<network compartment ocid>"
         "Allow dynamic-group \<dynamic group name> to use instances in compartment id \<deployment compartment ocid>" 
         ```
      * Set variable `create_dynamic_group_and_identity_policy` to `false`

4. OCI Configuration:
   * Valid OCI credentials set for the DEFAULT profile
   * The region in your profile should match the region of the deployment
   * See [OCI CLI Configuration Guide](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsconfigureocicli.htm)

5. Network Requirements:
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

## Deploying outside the Home Region
To deploy a cluster outside the home region, the following changes are required:
- Update the `region` variable in `terraform.tfvars` to the region where you want to deploy the cluster.
- Update the region for the DEFAULT profile in your `~/.oci/config` file to the region where you want to deploy the cluster.
- Update the `subnet_ocid` variable in `terraform.tfvars` to the subnet OCID of the subnet where you want to deploy the cluster.
- The Secrets Vaults for the cluster and persistent storage must be in the same region as the cluster.
- You must use a precreated dynamic group and identity policy created in the home region for the cluster.  Set `create_dynamic_group_and_identity_policy` to `false` in `terraform.tfvars`.  Follow the instruction in the [Prerequisites](#prerequisites) section 3.B to create the dynamic group and identity policy.

## Support

For issues beyond the scope of this module:
- Contact Qumulo support
- Consult OCI documentation
- Review Terraform logs

## License

See [LICENSE](LICENSE) file for details.
