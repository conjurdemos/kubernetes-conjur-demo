#!/bin/bash 
set -euo pipefail

. utils.sh

announce "Retrieving secrets using Conjur access token."

set_namespace $TEST_APP_NAMESPACE_NAME

sidecar_api_pod=$($cli get pods --ignore-not-found --no-headers -l app=test-app-api-sidecar | awk '{ print $1 }')
if [[ "$sidecar_api_pod" != "" ]]; then
  echo "Sidecar + REST API: $($cli exec -c $TEST_APP_NAMESPACE_NAME-app $sidecar_api_pod -- /webapp_v$CONJUR_VERSION.sh)"
fi

init_api_pod=$($cli get pods --ignore-not-found --no-headers -l app=test-app-api-init | awk '{ print $1 }')
if [[ "$init_api_pod" != "" ]]; then
  echo "Init Container + REST API: $($cli exec -c $TEST_APP_NAMESPACE_NAME-app $init_api_pod -- /webapp_v$CONJUR_VERSION.sh)"
fi
