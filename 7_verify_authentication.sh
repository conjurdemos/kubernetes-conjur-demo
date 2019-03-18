#!/bin/bash
set -euo pipefail

. utils.sh

function finish {
  readonly PIDS=(
    "SIDECAR_PORT_FORWARD_PID"
    "INIT_PORT_FORWARD_PID"
    "SECRETLESS_PORT_FORWARD_PID"
  )

  set +u

  echo -e "\n\nStopping all port-forwarding"
  for pid in "${PIDS[@]}"; do
    if [ -n "${!pid}" ]; then
      # Kill process, and swallow any errors
      kill ${!pid} > /dev/null 2>&1
    fi
  done
}
trap finish EXIT

announce "Validating that the deployments are functioning as expected."

set_namespace $TEST_APP_NAMESPACE_NAME

echo "Waiting for pods to become available"

while [[ $(pods_not_ready "test-app-summon-init") ]] ||
      [[ $(pods_not_ready "test-app-summon-sidecar") ]] ||
      [[ $(pods_not_ready "test-app-secretless") ]]; do
  printf "."
  sleep 1
done

if [[ "$PLATFORM" == "openshift" ]]; then
  echo "Waiting for deployments to become available"

  while [[ "$(deployment_status "test-app-summon-init")" != "Complete" ]] ||
        [[ "$(deployment_status "test-app-summon-sidecar")" != "Complete" ]] ||
        [[ "$(deployment_status "test-app-secretless")" != "Complete" ]]; do
    printf "."
    sleep 1
  done

  sidecar_pod=$(get_pod_name test-app-summon-sidecar)
  init_pod=$(get_pod_name test-app-summon-init)
  secretless_pod=$(get_pod_name test-app-secretless)

  # Routes are defined, but we need to do port-mapping to access them
  oc port-forward $sidecar_pod 8081:8080 > /dev/null 2>&1 &
  SIDECAR_PORT_FORWARD_PID=$!
  oc port-forward $init_pod 8082:8080 > /dev/null 2>&1 &
  INIT_PORT_FORWARD_PID=$!
  oc port-forward $secretless_pod 8083:8080 > /dev/null 2>&1 &
  SECRETLESS_PORT_FORWARD_PID=$!

  init_url="localhost:8081"
  sidecar_url="localhost:8082"
  secretless_url="localhost:8083"

  # Pause for the port-forwarding to complete setup
  sleep 10
else
  echo "Waiting for services to become available"
  while [ -z "$(service_ip "test-app-summon-init")" ] ||
        [ -z "$(service_ip "test-app-summon-sidecar")" ] ||
        [ -z "$(service_ip "test-app-secretless")" ]; do
    printf "."
    sleep 1
  done

  init_url=$(service_ip test-app-summon-init):8080
  sidecar_url=$(service_ip test-app-summon-sidecar):8080
  secretless_url=$(service_ip test-app-secretless):8080
fi

echo -e "\nAdding entry to the init app\n"
curl \
  -d '{"name": "Mr. Init"}' \
  -H "Content-Type: application/json" \
  $init_url/pet

echo -e "Adding entry to the sidecar app\n"
curl \
  -d '{"name": "Mr. Sidecar"}' \
  -H "Content-Type: application/json" \
  $sidecar_url/pet

echo -e "Adding entry to the secretless app\n"
curl \
  -d '{"name": "Mr. Secretless"}' \
  -H "Content-Type: application/json" \
  $secretless_url/pet

echo -e "Querying init app\n"
curl $init_url/pets

echo -e "\n\nQuerying sidecar app\n"
curl $sidecar_url/pets

echo -e "\n\nQuerying secretless app\n"
curl $secretless_url/pets
