#!/bin/bash
set -euo pipefail

. utils.sh

announce "Deploying test app."

set_namespace $TEST_APP_NAMESPACE_NAME

if ! [ "${DOCKER_EMAIL}" = "" ]; then
  announce "Creating image pull secret."
    
  kubectl delete --ignore-not-found secret conjurregcred

  kubectl create secret docker-registry conjurregcred \
    --docker-server=$DOCKER_REGISTRY_URL \
    --docker-username=$DOCKER_USERNAME \
    --docker-password=$DOCKER_PASSWORD \
    --docker-email=$DOCKER_EMAIL
fi

kubectl delete --ignore-not-found deployment test-app
kubectl delete --ignore-not-found service test-app

sleep 5

test_app_docker_image=$DOCKER_REGISTRY_PATH/test-app:$CONJUR_NAMESPACE_NAME

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_docker_image#g" ./test_app/test_app.yaml |
  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  sed -e "s#{{ SERVICE_ID }}#$AUTHENTICATOR_SERVICE_ID#g" |
  sed -e "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  kubectl create -f -

sleep 20

echo "Test app deployed."
