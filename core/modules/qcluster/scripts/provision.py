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
QCluster Node Provisioning Script

This script configures Qumulo cluster nodes during VM initialization on Oracle Cloud
Infrastructure (OCI). It performs the following operations:
- Extends the boot drive filesystem
- Installs required system packages
- Configures system services (SELinux, systemd services)
- Sets up network interface aliases
- Recreates a local NVMe namespace when the drive arrives with none
- Installs AWS CLI for object storage access
- Verifies access to object storage buckets
- Downloads and installs Qumulo Core software

The script is executed via cloud-init user_data during VM startup and logs all output
to /var/log/qumulo.log. Variables are provided by Terraform templatefile substitution.
"""

import glob
import json
import logging
import os
import re
import requests
import shutil
import subprocess
import time

from pathlib import Path
from typing import Any, Dict, List, Optional

# Template variables (replaced by Terraform templatefile)
qumulo_core_uri = "${qumulo_core_uri}"
object_storage_uris = "${object_storage_uris}"
access_key_id = "${access_key_id}"
secret_key = "${secret_key}"
object_storage_access_delay = int("${object_storage_access_delay}")

NVME_SYSFS_CLASS = "/sys/class/nvme"
# Measured on a healthy drive. tnvmcap/4096 is 12.9% larger and consumes the spare area;
# --block-size finds no matching FLBAS here.
NVME_NAMESPACE_MODEL = "SAMSUNG MZWLJ7T6HALA-00AU3"
NVME_NAMESPACE_BLOCKS = 1660481046
NVME_NAMESPACE_FLBAS = 2
TIMEOUT_NVME_COMMAND = 20
TIMEOUT_NVME_APPEAR = 30
NVME_REPAIR_WINDOW = 300
NVME_REPAIR_RETRY_DELAY = 10

TIMEOUT_PACKAGE_INSTALL = 600
TIMEOUT_DOWNLOAD = 900
TIMEOUT_SERVICE_OP = 60
DOWNLOAD_ATTEMPTS = 10
DOWNLOAD_RETRY_DELAY = 10


class ProvisioningError(Exception):
    pass


class TimeoutError(ProvisioningError):
    pass


def run_command(
    cmd: str,
    timeout: Optional[int] = None,
    quiet: bool = False,
) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.stdout.strip() and not quiet:
            logging.info(result.stdout.strip())
        if result.stderr.strip():
            logging.error(result.stderr.strip())

        return result
    except subprocess.TimeoutExpired as e:
        error_msg = f"Command timed out after {timeout} seconds: {cmd}"
        logging.error(error_msg)
        raise TimeoutError(error_msg) from e
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {cmd}")
        if e.stdout and e.stdout.strip():
            logging.info(e.stdout.strip())
        if e.stderr and e.stderr.strip():
            logging.error(e.stderr.strip())
        error_msg = f"Command failed with exit code {e.returncode}: {cmd}"
        raise ProvisioningError(error_msg) from e


def command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def run_command_with_retry(
    cmd: str,
    timeout: Optional[int] = None,
    attempts: int = DOWNLOAD_ATTEMPTS,
    delay: int = DOWNLOAD_RETRY_DELAY,
) -> subprocess.CompletedProcess:
    for attempt in range(1, attempts + 1):
        try:
            return run_command(cmd, timeout=timeout)
        except (ProvisioningError, TimeoutError):
            if attempt >= attempts:
                raise
            logging.warning(
                f"Command failed, retrying in {delay} seconds "
                f"(attempt {attempt} of {attempts}): {cmd}"
            )
            time.sleep(delay)


def install_package_with_retry(package_name: str) -> None:
    if command_exists(package_name):
        logging.info(f"{package_name} already installed")
        return

    logging.info(f"{package_name} not installed, installing...")

    for attempt in range(1, 6):
        try:
            run_command(
                f"dnf install -y {package_name}", timeout=TIMEOUT_PACKAGE_INSTALL
            )
            logging.info(f"Successfully installed {package_name}")
            return
        except (ProvisioningError, TimeoutError):
            if attempt >= 5:
                error_msg = f"Failed to install {package_name} after 5 attempts"
                raise ProvisioningError(error_msg)

            logging.warning(
                f"Could not get lock, retrying in 10 seconds... (Attempt: {attempt})"
            )
            time.sleep(10)


def configure_selinux() -> None:
    try:
        selinux_config = Path("/etc/selinux/config")
        if selinux_config.exists():
            content = selinux_config.read_text()
            content = re.sub(
                r"^SELINUX=.*", "SELINUX=permissive", content, flags=re.MULTILINE
            )
            selinux_config.write_text(content)
        else:
            logging.warning("/etc/selinux/config doesn't exist, skipping")

        run_command("setenforce Permissive", timeout=TIMEOUT_SERVICE_OP)
        logging.info("SELinux configured to permissive mode")
    except Exception as e:
        logging.warning(f"Failed to configure SELinux: {e}")


def disable_conflicting_services() -> None:
    def _stop_service_safely(service_name: str, not_found_message: str) -> None:
        try:
            run_command(f"systemctl stop {service_name}", timeout=TIMEOUT_SERVICE_OP)
            logging.info(f"Stopped {service_name}")
        except (ProvisioningError, TimeoutError):
            logging.warning(not_found_message)

    configure_selinux()

    services_to_stop = [
        ("systemd-timesyncd.service", "systemd-timesyncd not in use"),
        ("rpcbind.service", "rpcbind not in use"),
        ("firewalld.service", "firewalld not in use"),
    ]

    for service, error_msg in services_to_stop:
        _stop_service_safely(service, error_msg)

    services_to_mask = ["systemd-timesyncd", "rpcbind", "firewalld"]

    try:
        for service in services_to_mask:
            run_command(f"systemctl mask --now {service}", timeout=TIMEOUT_SERVICE_OP)

        run_command("systemctl disable rpcbind.socket", timeout=TIMEOUT_SERVICE_OP)
        run_command("systemctl mask rpcbind.socket", timeout=TIMEOUT_SERVICE_OP)

        logging.info("Successfully masked conflicting services")
    except (ProvisioningError, TimeoutError) as e:
        logging.warning(f"Service masking operation failed: {e}")

    try:
        run_command("sysctl --system", timeout=120)
        logging.info("Applied system configuration")
    except (ProvisioningError, TimeoutError) as e:
        logging.warning(f"sysctl --system failed: {e}")


def nvme_query(cmd: str) -> Dict[str, Any]:
    # Quiet: each query returns several KB of JSON.
    result = run_command(f"{cmd} -o json", timeout=TIMEOUT_NVME_COMMAND, quiet=True)
    return json.loads(result.stdout)


def nvme_namespace_dirs(controller: str) -> List[str]:
    return glob.glob(f"{NVME_SYSFS_CLASS}/{controller}/nvme*n*")


def repair_nvme_namespace(controller: str) -> None:
    device = f"/dev/{controller}"
    identity = nvme_query(f"nvme id-ctrl {device}")
    # --all lists unattached namespaces too; without it a retry allocates a second one.
    if not nvme_query(f"nvme list-ns --all {device}")["nsid_list"]:
        model = " ".join(identity["mn"].split())
        if model != NVME_NAMESPACE_MODEL:
            logging.error(
                f"{device} has no namespace; {model!r} is not a model this script can size"
            )
            return
        # A drive that merely lost its block device still holds data. Test it here, not at
        # the top: a partly repaired drive fails this and would never reach the attach.
        if identity["unvmcap"] != identity["tnvmcap"]:
            logging.error(f"{device} has no namespace but is not fully unallocated")
            return
        logging.warning(f"{device} arrived with no namespace; recreating it")
        run_command(
            f"nvme create-ns {device} --nsze={NVME_NAMESPACE_BLOCKS}"
            f" --ncap={NVME_NAMESPACE_BLOCKS} --flbas={NVME_NAMESPACE_FLBAS}",
            timeout=TIMEOUT_NVME_COMMAND,
        )
    if not nvme_query(f"nvme list-ns {device}")["nsid_list"]:
        run_command(
            f"nvme attach-ns {device} --namespace-id=1"
            f" --controllers={identity['cntlid']}",
            timeout=TIMEOUT_NVME_COMMAND,
        )
    # Without this the block device waits for the drive's namespace-changed event.
    run_command(f"nvme ns-rescan {device}", timeout=TIMEOUT_NVME_COMMAND)

    deadline = time.monotonic() + TIMEOUT_NVME_APPEAR
    while not nvme_namespace_dirs(controller):
        if time.monotonic() >= deadline:
            raise ProvisioningError(f"{device} has a namespace but no block device appeared")
        time.sleep(0.5)
    logging.warning(f"{device} namespace restored")


def repair_blank_nvme_namespaces() -> None:
    """Some OCI DenseIO instances hand over a local NVMe drive whose namespace has been deleted.
    Linux creates no block device and reports no error, because an empty namespace list is a
    valid response, so the node clusters with no read cache."""
    # A drive we cannot repair must not fail provisioning; the node clusters degraded.
    try:
        controllers = glob.glob(f"{NVME_SYSFS_CLASS}/nvme*")
        blank = [
            c
            for c in sorted(os.path.basename(p) for p in controllers)
            if re.fullmatch(r"nvme\d+", c) and not nvme_namespace_dirs(c)
        ]
        if not blank:
            return

        if not command_exists("nvme"):
            run_command_with_retry(
                "dnf install -y nvme-cli", timeout=TIMEOUT_PACKAGE_INSTALL
            )

        deadline = time.monotonic() + NVME_REPAIR_WINDOW
        for controller in blank:
            while True:
                try:
                    repair_nvme_namespace(controller)
                    break
                except Exception as e:
                    logging.error(f"Repair of /dev/{controller} failed: {e}")
                if time.monotonic() >= deadline:
                    break
                time.sleep(NVME_REPAIR_RETRY_DELAY)
    except Exception as e:
        logging.error(f"Could not check the local NVMe drives: {e}")


def get_vnic_metadata() -> List[Dict[str, str]]:
    headers = {"Authorization": "Bearer Oracle"}
    response = requests.get("http://169.254.169.254/opc/v2/vnics/", headers=headers)
    return response.json()


def create_qumulo_service() -> None:
    try:
        systemd_network = Path("/etc/systemd/network")
        systemd_network.mkdir(parents=True, exist_ok=True)

        vnic_metadata = get_vnic_metadata()
        mac_address = vnic_metadata[0]["macAddr"]

        link_content = f"""
[Match]
MACAddress={mac_address}

[Link]
AlternativeName=qumulo-frontend1
"""

        link_unit = systemd_network / "10-qumulo-frontend-link-altname.link"
        link_unit.write_text(link_content)
        link_unit.chmod(0o644)

        # Trigger a udev "add" event to force the altname to be aplied
        run_command(
            "udevadm trigger -c add",
            timeout=TIMEOUT_SERVICE_OP,
        )

        logging.info("Created and enabled Qumulo frontend link service")

    except Exception as e:
        error_msg = f"Failed to setup IP link name service: {e}"
        raise ProvisioningError(error_msg) from e


def download_and_install_aws_cli() -> None:
    install_package_with_retry("unzip")

    try:
        logging.info("Downloading AWS CLI...")
        run_command_with_retry(
            'curl -fL -C - "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"',
            timeout=TIMEOUT_DOWNLOAD,
        )

        logging.info("Extracting AWS CLI...")
        run_command("unzip -q awscliv2.zip", timeout=60)

        logging.info("Installing AWS CLI...")
        run_command("./aws/install", timeout=300)

        logging.info("AWS CLI installed successfully")

    except (ProvisioningError, TimeoutError) as e:
        error_msg = f"Failed to install AWS CLI: {e}"
        raise ProvisioningError(error_msg) from e


def verify_object_storage_access() -> None:
    def _test_s3_access(uri: str, timeout: int = 60) -> bool:
        """Test S3 bucket access, returns True if successful"""
        try:
            endpoint, bucket_name = uri.rsplit("/", 1)
            region = uri.split(".objectstorage.", 1)[1].split(".", 1)[0]

            cmd = (
                f'/usr/local/bin/aws --endpoint-url "{endpoint}" '
                f'--region "{region}" s3 ls "s3://{bucket_name}" --debug'
            )

            result = run_command(cmd, timeout=timeout)

            if result.returncode == 0:
                logging.info(f"Customer secret key has access to {uri}")
                return True
            else:
                logging.error(
                    f"Unexpected error accessing {uri}: \n{result.stdout}\n{result.stderr}"
                )
                return False

        except Exception as e:
            logging.error(f"Unexpected error accessing {uri}: {e}")
            return False

    if not access_key_id and not secret_key:
        logging.info("Skip S3 key verification for customer keys")
        return

    logging.info(
        f"Waiting {object_storage_access_delay} seconds before testing object storage "
        "access per OCI's instructions"
    )
    time.sleep(object_storage_access_delay)

    os.environ.update(
        {"AWS_ACCESS_KEY_ID": access_key_id, "AWS_SECRET_ACCESS_KEY": secret_key}
    )

    uri_list = object_storage_uris.split()
    for uri in uri_list:
        logging.info(f"Testing access to {uri}")

        while not _test_s3_access(uri):
            logging.warning(f"Retrying access to {uri} in 10 seconds...")
            time.sleep(10)


def download_and_install_qumulo() -> None:
    os.environ["QUMULO_NETWORK_MANAGED_BY_HOST"] = "true"

    logging.info(f"Downloading Qumulo Core from {qumulo_core_uri}")

    try:
        qumulo_rpm = Path("/tmp/qumulo-core.rpm")
        run_command_with_retry(
            f'curl -fL -C - -o {qumulo_rpm} "{qumulo_core_uri}"',
            timeout=TIMEOUT_DOWNLOAD,
        )

        logging.info("Installing Qumulo Core")

        run_command(f"dnf install -y {qumulo_rpm}", timeout=TIMEOUT_PACKAGE_INSTALL)

        result = run_command("dnf list installed | grep qumulo-core", timeout=30)

        if result.returncode == 0:
            logging.info("Qumulo Core installed successfully")
        else:
            error_msg = "Qumulo Core installation verification failed"
            raise ProvisioningError(error_msg)

    except (ProvisioningError, TimeoutError) as e:
        error_msg = f"Failed to install Qumulo Core: {e}"
        raise ProvisioningError(error_msg) from e


def main() -> None:
    logging.basicConfig(
        filename="/var/log/qumulo.log",
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        filemode="a",
    )

    # Validate required variables early to fail fast
    if not qumulo_core_uri:
        raise ProvisioningError("qumulo_core_uri not set")
    if not object_storage_uris:
        raise ProvisioningError("object_storage_uris not set")

    logging.info("Configuring instance environment")

    run_command("/usr/libexec/oci-growfs -y", timeout=300)
    logging.info("Extended boot drive filesystem")

    install_package_with_retry("systemd-container")
    install_package_with_retry("sysstat")

    disable_conflicting_services()

    repair_blank_nvme_namespaces()

    create_qumulo_service()

    download_and_install_aws_cli()

    verify_object_storage_access()

    download_and_install_qumulo()

    logging.info("Instance provisioning completed successfully")


if __name__ == "__main__":
    main()
