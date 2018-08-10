#!/bin/bash
set -eo pipefail

. utils.sh

announce "Deleting test app."

set_namespace $TEST_APP_NAMESPACE_NAME

if [ $PLATFORM = 'kubernetes' ]; then
  if ! [ "${DOCKER_EMAIL}" = "" ]; then
    announce "Creating image pull secret."
    
    kubectl delete --ignore-not-found secret dockerpullsecret
  fi
elif [ $PLATFORM = 'openshift' ]; then
  announce "Deleting image pull secret."
    
  $cli delete --ignore-not-found secrets dockerpullsecret
fi

$cli delete --ignore-not-found \
  deployment/test-app-api-sidecar \
  service/test-app-api-sidecar \
  serviceaccount/test-app-api-sidecar

if [ $PLATFORM = 'openshift' ]; then
  oc delete --ignore-not-found deploymentconfig/test-app-api-sidecar
fi

$cli delete --ignore-not-found \
  deployment/test-app-api-init \
  service/test-app-api-init \
  serviceaccount/test-app-api-init

if [ $PLATFORM = 'openshift' ]; then
  oc delete --ignore-not-found deploymentconfig/test-app-api-init
fi

sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" ./$PLATFORM/conjur-cli.yml |
  $cli delete -f -
 
echo "Test app deleted."
