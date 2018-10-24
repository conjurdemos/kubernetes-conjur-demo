#!/bin/bash
set -euo pipefail

. utils.sh

announce "Initializing Conjur certificate authority."

set_namespace $CONJUR_NAMESPACE_NAME

conjur_master=$(get_master_pod_name)

if [ $CONJUR_VERSION = '4' ]; then
  $cli exec $conjur_master -- conjur-plugin-service authn-k8s rake ca:initialize["conjur/authn-k8s/$AUTHENTICATOR_ID"] > /dev/null
elif [ $CONJUR_VERSION = '5' ]; then
  if [ $CONJUR_OSS = 'false' ]; then
    $cli exec $conjur_master -- chpst -u conjur conjur-plugin-service possum rake authn_k8s:ca_init["conjur/authn-k8s/$AUTHENTICATOR_ID"]
  elif [ $CONJUR_OSS = 'true' ]; then
    $cli exec $conjur_master -- bash -c "export CONJUR_ACCOUNT=$CONJUR_ACCOUNT; bundle exec rake authn_k8s:ca_init[\"conjur/authn-k8s/$AUTHENTICATOR_ID\"]"
  fi
fi

echo "Certificate authority initialized."
