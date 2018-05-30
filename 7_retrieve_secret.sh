#!/bin/bash
set -euo pipefail

. utils.sh

announce "Retrieving secrets using Conjur access token."

set_namespace $TEST_APP_NAMESPACE_NAME

sidecar_api_pod=$($cli get pods --no-headers -l app=test-app-api-sidecar | awk '{ print $1 }')
init_api_pod=$($cli get pods --no-headers -l app=test-app-api-init | awk '{ print $1 }')

echo "Sidecar + Ruby API - $($cli exec -c test-app $sidecar_api_pod -- curl -s localhost:3000)"
echo "Init Container + Ruby API - $($cli exec -c test-app $init_api_pod -- curl -s localhost:3000)"
