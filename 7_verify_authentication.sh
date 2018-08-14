#!/bin/bash
set -euo pipefail

. utils.sh

announce "Validating that the deployments are functioning as expected."

set_namespace $TEST_APP_NAMESPACE_NAME

# Kubernetes and OpenShift currently deploy different apps; verify differently
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
