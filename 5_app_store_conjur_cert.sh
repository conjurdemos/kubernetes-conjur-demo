#!/usr/bin/env bash
set -euo pipefail

. utils.sh

announce "Storing Conjur cert for test app configuration."

set_namespace $CONJUR_NAMESPACE_NAME

echo "Retrieving Conjur certificate."

if [[ "$CONJUR_OSS_HELM_INSTALLED" == "true" ]]; then
  master_pod_name=$(get_master_pod_name)
  ssl_cert=$($cli exec -c "${HELM_RELEASE}-nginx" $master_pod_name -- cat /opt/conjur/etc/ssl/cert/tls.crt)
else
  if $cli get pods --selector role=follower --no-headers; then
    follower_pod_name=$($cli get pods --selector role=follower --no-headers | awk '{ print $1 }' | head -1)
    ssl_cert=$($cli exec $follower_pod_name -- cat /opt/conjur/etc/ssl/conjur.pem)
  else
    echo "Regular follower not found. Trying to assume a decomposed follower..."
    follower_pod_name=$($cli get pods --selector role=decomposed-follower --no-headers | awk '{ print $1 }' | head -1)
    ssl_cert=$($cli exec -c "nginx" $follower_pod_name -- cat /opt/conjur/etc/ssl/cert/tls.crt)
  fi
fi

set_namespace $TEST_APP_NAMESPACE_NAME

echo "Storing non-secret conjur cert as test app configuration data"

$cli delete --ignore-not-found=true configmap $TEST_APP_NAMESPACE_NAME

# Store the Conjur cert in a ConfigMap.
$cli create configmap $TEST_APP_NAMESPACE_NAME --from-file=ssl-certificate=<(echo "$ssl_cert")

echo "Conjur cert stored."
