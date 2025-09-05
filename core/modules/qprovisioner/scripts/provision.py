#!/usr/bin/env python3
#
# MIT License
#
# Copyright (c) 2025 Qumulo
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

"""
QProvisioner Node Provisioning Script

This script provisions and manages Qumulo clusters on Oracle Cloud Infrastructure (OCI).
It performs cluster creation, node management, capacity adjustments, and network configuration.
The script is executed via cloud-init user_data during VM startup and logs all output
to /var/log/qumulo.log. Variables are provided by Terraform templatefile substitution.
"""

import base64
import json
import logging
import os
import re
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import requests

# Template variables (replaced by Terraform templatefile)
cluster_node_ip_addresses = "${cluster_node_ip_addresses}"
clustering_node_ip_address = "${clustering_node_ip_address}"
qumulo_core_rpm_bucket_name = "${qumulo_core_rpm_bucket_name}"
qumulo_core_rpm_object_name = "${qumulo_core_rpm_object_name}"


@dataclass
class ProvisioningConfig:
    # Cluster settings
    cluster_name: str
    admin_password: str
    product_type: str

    # Node settings
    node_count: int
    node_ips_and_fault_domains: str

    # Storage settings
    storage_uris: str
    soft_capacity_limit: str
    permanent_disk_count: str

    # Network settings
    floating_ips: str
    netmask: str

    # Secret settings
    secret_ocid: str
    cluster_node_count_secret_id: str
    deployed_permanent_disk_count_secret_id: str
    cluster_soft_capacity_limit_secret_id: str
    provisioner_complete_secret_id: str

    # Deployment settings
    dev_environment: str
    clustering_node_ocid: str


def create_provisioning_config() -> ProvisioningConfig:
    """Create ProvisioningConfig from template variables"""
    return ProvisioningConfig(
        cluster_name="${cluster_name}",
        admin_password="${admin_password}",
        product_type="${product_type}",
        dev_environment="${dev_environment}",
        node_count=int("${node_count}"),
        node_ips_and_fault_domains="${node_ip_addresses_and_fault_domains}",
        clustering_node_ocid="${clustering_node_ocid}",
        storage_uris="${object_storage_uris}",
        soft_capacity_limit="${soft_capacity_limit}",
        permanent_disk_count="${permanent_disk_count}",
        floating_ips="${floating_ip_addresses}",
        netmask="${netmask}",
        secret_ocid="${secret_ocid}",
        cluster_node_count_secret_id="${cluster_node_count_secret_id}",
        provisioner_complete_secret_id="${provisioner_complete_secret_id}",
        deployed_permanent_disk_count_secret_id="${deployed_permanent_disk_count_secret_id}",
        cluster_soft_capacity_limit_secret_id="${cluster_soft_capacity_limit_secret_id}",
    )


class ProvisioningError(Exception):
    pass


def run_command(
    cmd: str, timeout: Optional[int] = None, check: bool = True
) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=check,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.stdout.strip():
            logging.info(result.stdout.strip())
        if result.stderr.strip():
            logging.error(result.stderr.strip())
        return result
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {cmd}")
        if e.stdout and e.stdout.strip():
            logging.info(e.stdout.strip())
        if e.stderr and e.stderr.strip():
            logging.error(e.stderr.strip())
        error_msg = f"Command failed with exit code {e.returncode}: {cmd}"
        raise ProvisioningError(error_msg) from e


def qq_command(args: str, timeout: int = 300) -> subprocess.CompletedProcess:
    cmd = f"./qq --host {clustering_node_ip_address} {args}"
    return run_command(cmd, timeout=timeout)


def update_secret(secret_id: str, value: str) -> None:
    """Update an OCI vault secret with base64-encoded value"""
    run_command(
        f"/root/bin/oci vault secret update-base64 --secret-id {secret_id} "
        f'--secret-content-content "$(echo {value} | base64)" --auth instance_principal'
    )


def install_oci_cli() -> None:
    cmd = (
        "curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/"
        "install.sh | bash -s -- --accept-all-defaults"
    )
    run_command(cmd, timeout=600)


def wait_for_qfsd_installation(cluster_node_ip_addresses: str) -> None:
    for ip in cluster_node_ip_addresses.split():
        while True:
            try:
                response = requests.get(
                    f"https://{ip}:8000/v1/node/state", verify=False, timeout=60
                )
                if response.status_code == 200:
                    logging.info(f"QFSD is up on node {ip}")
                    break
            except requests.RequestException:
                pass

            logging.info(f"Waiting for QFSD to be up and running on node {ip}")
            time.sleep(10)


def clean_up_qumulo_core_rpm(bucket_name: str, object_name: str) -> None:
    if bucket_name != "" and object_name != "":
        # If the object does not exist in the bucket, don't let that fail provisioning. If it fails
        # to be deleted, qfsd will catch it later when the cluster is formed.
        run_command(
            f'/root/bin/oci os object delete --bucket-name "{bucket_name}" --object-name "{object_name}"'
            "--auth instance_principal",
            check=False,
        )


def get_qfsd_version(ip: str) -> str:
    result = qq_command(f"--host {ip} version")
    for line in result.stdout.split("\n"):
        if "revision_id" in line:
            return re.sub(r"[^0-9.]", "", line)
    return ""


def download_qq_client() -> None:
    response = requests.get(
        f"https://{clustering_node_ip_address}/static/qq", verify=False
    )
    with open("qq", "wb") as f:
        f.write(response.content)
    os.chmod("qq", 0o777)


def survey_node_state(
    qfsd_version: str, cluster_node_ip_addresses: str
) -> Tuple[List[str], List[str]]:
    in_quorum_nodes = []
    unconfigured_nodes = []
    out_of_quorum_nodes = []

    for ip in cluster_node_ip_addresses.split():
        node_version = get_qfsd_version(ip)

        if node_version != qfsd_version:
            raise ProvisioningError(
                f"Node at {ip} has the wrong qfsd revision {node_version}. "
                f"Please make sure all nodes are at revision {qfsd_version}"
            )

        try:
            quorum_result = qq_command(f"--host {ip} node_state_get")
            if "ACTIVE" in quorum_result.stdout:
                in_quorum_nodes.append(ip)
            elif "UNCONFIGURED" in quorum_result.stdout:
                unconfigured_nodes.append(ip)
            else:
                out_of_quorum_nodes.append(ip)
        except ProvisioningError:
            out_of_quorum_nodes.append(ip)

    logging.info(
        f"{len(unconfigured_nodes)} nodes unconfigured, {len(out_of_quorum_nodes)} nodes "
        f"out of quorum, {len(in_quorum_nodes)} nodes in quorum"
    )

    return in_quorum_nodes, out_of_quorum_nodes


def wait_for_new_quorum() -> None:
    while True:
        try:
            result = qq_command("node_state_get", timeout=60)
            if "ACTIVE" in result.stdout:
                logging.info("New quorum formed")
                break
        except ProvisioningError:
            pass

        logging.info("Waiting for new quorum")
        time.sleep(10)


def apply_initial_floating_ips(flips: List[str], netmask: str) -> None:
    if not flips:
        return

    flips_json = ", ".join(f'"{ip}"' for ip in flips)

    logging.info(f"Apply network configuration with floating IPs: {flips_json}")

    network_config = f"""{{
        "frontend_networks": [
            {{
                "id": 1,
                "name": "default",
                "addresses": {{
                    "type": "HOST",
                    "host_addresses": {{
                        "floating_ip_ranges": [{flips_json}],
                        "netmask": "{netmask}"
                    }}
                }}
            }}
        ]
    }}"""

    qq_command(
        f"raw --content-type application/json PUT /v3/network <<< '{network_config}'"
    )

    while True:
        try:
            result = qq_command("raw GET /v3/network/status")
            if "floating_addresses" in result.stdout:
                logging.info("Network configuration applied")
                break
        except ProvisioningError:
            pass

        logging.info("Waiting for network configuration to apply")
        time.sleep(10)


def maybe_update_floating_ips(
    clustering_node_ip_address: str,
    floating_ip_addresses: str,
    netmask: str,
    qfsd_version: str,
) -> None:
    if not qfsd_version or int(qfsd_version.replace(".", "")[:3]) < 751:
        return

    qq_command("network_v3_get_config -o network_config.json")

    with open("network_config.json", "r") as f:
        current_config = json.load(f)

    new_flips = floating_ip_addresses.split(",") if floating_ip_addresses else []

    frontend_networks_length = len(current_config.get("frontend_networks", []))
    floating_ip_count = (
        len(
            current_config["frontend_networks"][0]
            .get("addresses", {})
            .get("host_addresses", {})
            .get("floating_ip_ranges", [])
        )
        if frontend_networks_length > 0
        else 0
    )

    if frontend_networks_length == 0 or floating_ip_count == 0:
        logging.info("No floating IPs configured, applying initial floating IPs")
        apply_initial_floating_ips(new_flips, netmask)
        return

    current_flips = current_config["frontend_networks"][0]["addresses"][
        "host_addresses"
    ]["floating_ip_ranges"]

    if current_flips != new_flips:
        if not new_flips:
            logging.info("Floating IPs set to None, clearing network config.")
            current_config["frontend_networks"] = []
        else:
            new_flips_json = [ip for ip in new_flips]
            logging.info(f"Updating floating IPs to {new_flips_json}")
            current_config["frontend_networks"][0]["addresses"]["host_addresses"][
                "floating_ip_ranges"
            ] = new_flips_json

        with open("network_config.json", "w") as f:
            json.dump(current_config, f)

        qq_command("network_v3_put_config --file network_config.json")
        wait_for_new_quorum()


def update_cluster_membership(
    node_count: int, node_ips_and_fault_domains: str, cluster_node_count_secret_id: str
) -> None:
    ips_and_fault_domains = node_ips_and_fault_domains.split()
    new_node_membership = ips_and_fault_domains[:node_count]

    args = [
        "modify_object_backed_cluster_membership",
        f"--node-ips-and-fault-domains {' '.join(new_node_membership)}",
        "--batch",
    ]

    logging.info(
        f"Running cluster membership change command: ./qq --host {clustering_node_ip_address} "
        f"{' '.join(args)}"
    )
    qq_command(" ".join(args))

    wait_for_new_quorum()

    # Wait for membership change to take effect
    while True:
        try:
            result = qq_command("get_object_backed_nodes")
            node_data = json.loads(result.stdout.replace("'", '"'))
            current_node_count = len(
                node_data["membership"]["node_ips_and_fault_domains"]
            )
            if current_node_count == node_count:
                logging.info("New cluster membership in effect")
                break
            logging.info(
                f"Waiting for new cluster membership to take effect. "
                f"Current node count {current_node_count}"
            )
        except (ProvisioningError, json.JSONDecodeError, KeyError, IndexError):
            pass
        time.sleep(10)

    # Update secret with new node count
    update_secret(cluster_node_count_secret_id, str(len(new_node_membership)))


def create_cluster(config: ProvisioningConfig) -> None:
    if config.node_count == 0:
        return

    logging.info(
        f"All of the nodes are out of quorum, forming a new cluster with {config.node_count} nodes."
    )

    ips_and_fault_domains = config.node_ips_and_fault_domains.split()
    flips = config.floating_ips.split(",") if config.floating_ips else []

    new_nodes = ips_and_fault_domains[: config.node_count]

    cluster_create_args = [
        "create_object_backed_cluster",
        f"--cluster-name {config.cluster_name}",
        f"--admin-password {config.admin_password}",
        f"--host-instance-id {config.clustering_node_ocid}",
        "--accept-eula",
        f"--usable-capacity-clamp {config.soft_capacity_limit}TB",
        f"--product-type {config.product_type}",
        f"--object-storage-uris {config.storage_uris}",
        f"--node-ips-and-fault-domains {' '.join(new_nodes)}",
        f"--key-vault {config.secret_ocid}",
    ]

    logging.info(
        f"Running cluster create command: ./qq --host {clustering_node_ip_address} "
        f"{' '.join(cluster_create_args)}"
    )
    qq_command(" ".join(cluster_create_args))

    # Record cluster metadata in secrets
    update_secret(config.cluster_node_count_secret_id, str(len(new_nodes)))
    update_secret(
        config.deployed_permanent_disk_count_secret_id, config.permanent_disk_count
    )
    update_secret(
        config.cluster_soft_capacity_limit_secret_id, config.soft_capacity_limit
    )

    qq_command(f"login -u admin -p {config.admin_password}")

    logging.info("Setting s3 object client timeout limit to 10s")
    qq_command(
        "raw --content-type application/json PUT "
        '/v1/tunables/s3_object_client_socket_recv_timeout_ms <<< \'{"configured_value": "10000"}\''
    )

    if config.dev_environment == "true":
        qq_command(
            "set_monitoring_conf --mq-host staging-missionq.qumulo.com "
            "--nexus-host api.spog-staging.qumulo.com"
        )

    apply_initial_floating_ips(flips, config.netmask)

    logging.info("Restart quorum to ensure cluster is ready for client access")
    qq_command("raw POST /v1/debug/quorum/abandon")
    wait_for_new_quorum()


def handle_existing_cluster(
    in_quorum_nodes: List[str],
    config: ProvisioningConfig,
    clustering_node_ip_address: str,
    qfsd_version: str,
) -> None:
    qq_command(f"login -u admin -p {config.admin_password}")

    # Node add/remove
    if len(in_quorum_nodes) != config.node_count:
        logging.info(
            f"Change the number of nodes in the cluster from {len(in_quorum_nodes)} to {config.node_count}"
        )
        update_cluster_membership(
            config.node_count,
            config.node_ips_and_fault_domains,
            config.cluster_node_count_secret_id,
        )

    # Bucket add
    current_bucket_result = qq_command("get_object_storage_uris")
    current_bucket_json = current_bucket_result.stdout.replace("'", '"')
    current_bucket_count = len(json.loads(current_bucket_json))
    storage_uris = config.storage_uris.split()

    if current_bucket_count < len(storage_uris):
        logging.info(
            f"Updating the cluster to use the following buckets: {config.storage_uris}"
        )
        qq_command(f"add_object_storage_uris --uris {config.storage_uris}")
        wait_for_new_quorum()

    # Capacity increase
    cmd = (
        f"/root/bin/oci secrets secret-bundle get --secret-id "
        f"{config.cluster_soft_capacity_limit_secret_id} --auth instance_principal"
    )
    result = run_command(cmd)
    secret_data = json.loads(result.stdout)
    encoded_content = secret_data["data"]["secret-bundle-content"]["content"]
    current_capacity_in_tb = base64.b64decode(encoded_content).decode()

    logging.info(f"Current cluster capacity in TB: {current_capacity_in_tb}")
    if int(current_capacity_in_tb) < int(config.soft_capacity_limit):
        logging.info(f"Increasing cluster capacity to {config.soft_capacity_limit}TB")
        qq_command(f"capacity_clamp_set --clamp {config.soft_capacity_limit}TB")
        wait_for_new_quorum()

        # Update secret with new capacity
        update_secret(
            config.cluster_soft_capacity_limit_secret_id, config.soft_capacity_limit
        )

    # Floating IP update on versions >= 7.5.1
    maybe_update_floating_ips(
        clustering_node_ip_address, config.floating_ips, config.netmask, qfsd_version
    )


def signal_complete(config: ProvisioningConfig) -> None:
    update_secret(config.provisioner_complete_secret_id, "true")


def shutdown_instance(config: ProvisioningConfig) -> None:
    if config.dev_environment == "true":
        # Skip shutting down the provisioner for dev environments so we can gather provisioner logs.
        return

    instance_metadata = requests.get(
        "http://169.254.169.254/opc/v2/instance/",
        headers={"Authorization": "Bearer Oracle"},
        timeout=30,
    )
    instance_id = instance_metadata.json()["id"]

    run_command(
        f"/root/bin/oci compute instance action --instance-id {instance_id} "
        f"--action STOP --auth instance_principal"
    )


def main() -> None:
    logging.basicConfig(
        filename="/var/log/qumulo.log",
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        filemode="a",
    )

    logging.info("Starting QProvisioner provisioning")

    os.chdir("/root")
    install_oci_cli()
    wait_for_qfsd_installation(cluster_node_ip_addresses)
    clean_up_qumulo_core_rpm(qumulo_core_rpm_bucket_name, qumulo_core_rpm_object_name)
    download_qq_client()

    qfsd_version = get_qfsd_version(clustering_node_ip_address)
    in_quorum_nodes, out_of_quorum_nodes = survey_node_state(
        qfsd_version, cluster_node_ip_addresses
    )

    if out_of_quorum_nodes:
        raise ProvisioningError(
            f"Found out of quorum nodes at IPs {out_of_quorum_nodes}, "
            f"abort operation. Please come back when the cluster is in a healthy state"
        )

    config = create_provisioning_config()

    if not in_quorum_nodes:
        create_cluster(config)
    else:
        handle_existing_cluster(
            in_quorum_nodes, config, clustering_node_ip_address, qfsd_version
        )

    logging.info("QProvisioner provisioning completed successfully")
    signal_complete(config)
    shutdown_instance(config)


if __name__ == "__main__":
    main()
