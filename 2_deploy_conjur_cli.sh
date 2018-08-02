#!/bin/bash 
set -euo pipefail

. utils.sh

announce "Deploying Conjur CLI."

set_namespace $TEST_APP_NAMESPACE_NAME

sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" ./$PLATFORM/conjur-cli.yml |
  $cli create -f -

wait_for_it 300 "$cli describe po conjur-cli | grep Status: | grep -c Running"

echo "Conjur CLI is running."
