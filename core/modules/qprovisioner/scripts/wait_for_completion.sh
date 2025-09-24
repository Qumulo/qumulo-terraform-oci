#!/bin/bash -e
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

secret_id="${secret_id}"

max_retries=30
count=0

while true; do
    if [ $count -gt $max_retries ]; then
        echo "Cluster Provisioning FAILED"
        echo "Review /var/log/qumulo.log on the provisioner instance to troubleshoot"
        exit 1
    fi

    contents="$(oci secrets secret-bundle get --secret-id $secret_id)"
    value="$(echo $contents | jq '.data["secret-bundle-content"].content' -r | base64 -d)"

    if [ "$value" == "true" ]; then
        break;
    fi

    echo "Waiting for provisioning to complete"
    count=$((count + 1))
    sleep 30
done
echo "Cluster provisioning complete"

oci vault secret update-base64 \
    --secret-id $secret_id \
    --secret-content-content "$(echo -n false | base64)"
