#!/bin/bash
set -ux

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish.
#### This script has to poweron the server and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

export VM_NAME=$(echo $BMC_ENDPOINT | awk -F "_" '{print $1}')
export VM_NAMESPACE=$(echo $BMC_ENDPOINT | awk -F "_" '{print $2}')

start_vm() {
    VM_NAMESPACE=$1
    VM_NAME=$2
    max_tries=5
    tries=0

    virtctl -n ${VM_NAMESPACE} start ${VM_NAME}
    while true; do
        output=$(virtctl -n ${VM_NAMESPACE} start ${VM_NAME} 2>&1 >/dev/null)
        if grep -q "VM is already running" <<< "${output}"; then
            return 0
        else
            if [[ ${tries} -gt ${max_tries} ]]; then
                return 1
            fi
            tries=$(( ${tries} + 1 ))
            echo "Waiting to power on the VM..."
            sleep 5
        fi
    done
}

if [[ -r /var/tmp/kubeconfig ]]; then
    export KUBECONFIG=/var/tmp/kubeconfig
fi

VM_RUNNING=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.running}')
if [ $? -eq 1 ]; then
  echo "Failed to get VM power state."
  exit 1
fi

if [[ "${VM_RUNNING}" == "true" ]]; then
  echo "VM is already running"
else
  start_vm ${VM_NAMESPACE} ${VM_NAME}
  if [ $? -eq 0 ]; then
      echo "VM is running"
      exit 0
  else
      echo "Failed to poweron VM"
      exit 1
  fi
fi
