#!/bin/bash
set -eo pipefail

. utils.sh

announce "Deploying test app."

set_namespace $TEST_APP_NAMESPACE_NAME

if [ $PLATFORM = 'kubernetes' ]; then
  if ! [ "${DOCKER_EMAIL}" = "" ]; then
    announce "Creating image pull secret."
    
    kubectl delete --ignore-not-found secret dockerpullsecret

    kubectl create secret docker-registry dockerpullsecret \
      --docker-server=$DOCKER_REGISTRY_URL \
      --docker-username=$DOCKER_USERNAME \
      --docker-password=$DOCKER_PASSWORD \
      --docker-email=$DOCKER_EMAIL
  fi
elif [ $PLATFORM = 'openshift' ]; then
  announce "Creating image pull secret."
    
  $cli delete --ignore-not-found secrets dockerpullsecret
  
  $cli secrets new-dockercfg dockerpullsecret \
    --docker-server=${DOCKER_REGISTRY_PATH} \
    --docker-username=_ \
    --docker-password=$($cli whoami -t) \
    --docker-email=_
  
  $cli secrets add serviceaccount/default secrets/dockerpullsecret --for=pull    
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

sleep 5

test_app_docker_image=$(platform_image test-app)

conjur_appliance_url=https://conjur-follower.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api
conjur_authenticator_url=https://conjur-follower.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api/authn-k8s/$AUTHENTICATOR_ID

if [ $CONJUR_VERSION = '4' ]; then
  conjur_authn_login_prefix=$TEST_APP_NAMESPACE_NAME/service_account
elif [ $CONJUR_VERSION = '5' ]; then
  conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps/$TEST_APP_NAMESPACE_NAME/service_account
fi

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_docker_image#g" ./$PLATFORM/test-app-api-sidecar.yml |
  sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" |
  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
  sed -e "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
  sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
  sed -e "s#{{ CONJUR_AUTHENTICATOR_URL }}#$conjur_authenticator_url#g" |
  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
  sed -e "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  sed -e "s#{{ CONJUR_VERSION }}#'$CONJUR_VERSION'#g" |
  $cli create -f -

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_docker_image#g" ./$PLATFORM/test-app-api-init.yml |
  sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" |
  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
  sed -e "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
  sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
  sed -e "s#{{ CONJUR_AUTHENTICATOR_URL }}#$conjur_authenticator_url#g" |
  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
  sed -e "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  sed -e "s#{{ CONJUR_VERSION }}#'$CONJUR_VERSION'#g" |
  $cli create -f -

sleep 20

echo "Test app deployed."
