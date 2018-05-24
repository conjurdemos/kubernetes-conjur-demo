#!/bin/bash 
set -euo pipefail

. utils.sh

announce "Creating Test App namespace."

set_namespace default

if has_namespace "$TEST_APP_NAMESPACE_NAME"; then
  echo "Namespace '$TEST_APP_NAMESPACE_NAME' exists, not going to create it."
  set_namespace $TEST_APP_NAMESPACE_NAME
else
  echo "Creating '$TEST_APP_NAMESPACE_NAME' namespace."

  if [ $PLATFORM = 'kubernetes' ]; then
    $cli create namespace $TEST_APP_NAMESPACE_NAME
  elif [ $PLATFORM = 'openshift' ]; then
    $cli new-project $TEST_APP_NAMESPACE_NAME
  fi
  
  set_namespace $TEST_APP_NAMESPACE_NAME
fi

$cli delete --ignore-not-found rolebinding test-app-conjur-authenticator-role-binding

sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" ./$PLATFORM/test-app-conjur-authenticator-role-binding.yaml |
  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" |
  $cli create -f -
