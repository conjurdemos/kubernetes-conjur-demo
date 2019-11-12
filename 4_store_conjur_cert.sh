#!/bin/bash
set -euo pipefail

. utils.sh

announce "Storing Conjur cert for test app configuration."

set_namespace $CONJUR_NAMESPACE_NAME

echo "Retrieving Conjur certificate."

role="master"
selector="app=conjur-cli"
cert_location="/root/conjur-${CONJUR_ACCOUNT}.pem"
if [ $CONJUR_DEPLOYMENT == "dap" ]; then
  role="follower"
  selector="role=follower"
  cert_location="/opt/conjur/etc/ssl/conjur.pem"
fi

if $cli get pods --selector role=$role --no-headers; then
  conjur_pod_name=$($cli get pods \
                      --selector=$selector \
                      --no-headers | awk '{ print $1 }' | head -1)
  ssl_cert=$($cli exec "${conjur_pod_name}" cat $cert_location)
else
  echo "Regular follower not found. Trying to assume a decomposed follower..."
  conjur_pod_name=$($cli get pods \
                      --selector role=decomposed-follower \
                      --no-headers | awk '{ print $1 }' | head -1)
  ssl_cert=$($cli exec -c "nginx" $conjur_pod_name -- cat /opt/conjur/etc/ssl/cert/tls.crt)
fi

set_namespace $TEST_APP_NAMESPACE_NAME

echo "Storing non-secret conjur cert as test app configuration data"

$cli delete --ignore-not-found=true configmap $TEST_APP_NAMESPACE_NAME

# Store the Conjur cert in a ConfigMap.
$cli create configmap $TEST_APP_NAMESPACE_NAME --from-file=ssl-certificate=<(echo "$ssl_cert")

echo "Conjur cert stored."
