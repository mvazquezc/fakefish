#!/bin/bash
set -ux

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish.
#### This script has to unmount the iso from the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

# Disconnect image

export VM_NAME=$(echo $BMC_ENDPOINT | awk -F "_" '{print $1}')
export VM_NAMESPACE=$(echo $BMC_ENDPOINT | awk -F "_" '{print $2}')

if [[ -r /var/tmp/kubeconfig ]]; then
    export KUBECONFIG=/var/tmp/kubeconfig
fi

# we need to poweroff the VM if it's running
VM_RUNNING=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.running}')
if [ $? -eq 1 ]; then
  echo "Failed to get VM power state."
  exit 1
fi
VM_WAS_RUNNING=false
if [[ "${VM_RUNNING}" == "true" ]]; then
  VM_WAS_RUNNING="true"
  virtctl -n ${VM_NAMESPACE} stop ${VM_NAME}
  if [ $? -eq 1 ]; then
    echo "Failed to poweroff VM"
    exit 1
  fi
fi

NUM_DISK=( $(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.domain.devices.disks[*].name}') )
if [[ $? -eq 1 ]]; then
  echo "Failed to get VM disks."
  exit 1
fi

cat <<EOF > /tmp/${VM_NAME}.patch
[
  {
    "op": "remove",
    "path": "/spec/template/spec/domain/devices/disks/$(( ${#NUM_DISK[@]} - 1 ))"
  }
]
EOF

# If NUM_DISK is <=1 means that mount didn't happen
if [[ ${#NUM_DISK[@]} -gt 1 ]]; then
  oc -n ${VM_NAMESPACE} patch vm ${VM_NAME} --patch-file /tmp/${VM_NAME}.patch --type json
  if [ $? -eq 1 ]; then
    echo "Failed to remove ISO disk from VM"
    exit 1
  fi
else
  echo "No ISO disk in VM"
fi

NUM_VOLUMES=( $(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.volumes[*].name}') )
if [[ $? -eq 1 ]]; then
  echo "Failed to get VM volumes."
  exit 1
fi

cat <<EOF > /tmp/${VM_NAME}.patch
[
  {
    "op": "remove",
    "path": "/spec/template/spec/volumes/$(( ${#NUM_VOLUMES[@]} - 1 ))"
  }
]
EOF

# If NUM_VOLUMES is <=1 means that mount didn't happen
if [[ ${#NUM_VOLUMES[@]} -gt 1 ]]; then
  oc -n ${VM_NAMESPACE} patch vm ${VM_NAME} --patch-file /tmp/${VM_NAME}.patch --type json
  if [ $? -eq 0 ]; then
    oc -n ${VM_NAMESPACE} delete configmap ${VM_NAME}-iso-ca &> /dev/null
    oc -n ${VM_NAMESPACE} delete pvc ${VM_NAME}-bootiso
    if [ $? -eq 1 ]; then
      echo "Failed to delete CDI ISO PVC."
      exit 1
    fi
  else
    echo "Failed to remove iso volume from VM"
    exit 1
  fi
else
  echo "No ISO Volume in VM"
fi

# If VM was running, restore it
if [[ "${VM_WAS_RUNNING}" == "true" ]]; then
  virtctl -n ${VM_NAMESPACE} start ${VM_NAME}
  if [ $? -eq 1 ]; then
    echo "Failed to poweron VM"
    exit 1
  fi
fi