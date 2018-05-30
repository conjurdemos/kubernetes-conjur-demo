#!/bin/bash 
set -euo pipefail

. utils.sh

announce "Storing Conjur cert for test app configuration."

set_namespace $CONJUR_NAMESPACE_NAME

echo "Retrieving Conjur certificate."

follower_pod_name=$($cli get pods -l role=follower --no-headers | awk '{ print $1 }' | head -1)
ssl_cert=$($cli exec $follower_pod_name -- cat /opt/conjur/etc/ssl/conjur.pem)

set_namespace $TEST_APP_NAMESPACE_NAME

echo "Storing non-secret conjur cert as test app configuration data"

$cli delete --ignore-not-found=true configmap $TEST_APP_NAMESPACE_NAME

# Store the Conjur cert in a ConfigMap.
$cli create configmap $TEST_APP_NAMESPACE_NAME --from-file=ssl-certificate=<(echo "$ssl_cert")

echo "Conjur cert stored."
