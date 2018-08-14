#!/bin/bash
set -eo pipefail

. utils.sh

main() {
  announce "Deploying test apps for $TEST_APP_NAMESPACE_NAME."

  set_namespace $TEST_APP_NAMESPACE_NAME
  init_registry_creds
  init_connection_specs

  if is_minienv; then
    IMAGE_PULL_POLICY='Never'
  else
    IMAGE_PULL_POLICY='Always'
  fi

  deploy_app_backend
  deploy_secretless_app
  deploy_sidecar_app
  deploy_init_container_app
  sleep 15  # allow time for containers to initialize
}

###########################
init_registry_creds() {
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
}

###########################
init_connection_specs() {
  test_sidecar_app_docker_image=$(platform_image test-sidecar-app)
  test_init_app_docker_image=$(platform_image test-init-app)

  if [[ $LOCAL_AUTHENTICATOR == true ]]; then
    authenticator_client_image=$(platform_image conjur-authn-k8s-client)
  else
    authenticator_client_image="cyberark/conjur-kubernetes-authenticator"
  fi

  conjur_appliance_url=https://conjur-follower.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api
  conjur_authenticator_url=https://conjur-follower.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api/authn-k8s/$AUTHENTICATOR_ID

  conjur_authn_login_prefix=""
  if [ $CONJUR_VERSION = '4' ]; then
    conjur_authn_login_prefix=$TEST_APP_NAMESPACE_NAME/service_account
  elif [ $CONJUR_VERSION = '5' ]; then
    conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps/$TEST_APP_NAMESPACE_NAME/service_account
  fi
}

###########################
deploy_app_backend() {
  $cli delete --ignore-not-found \
     service/test-summon-init-app-backend \
     service/test-summon-sidecar-app-backend \
     service/test-secretless-app-backend \
     statefulset/summon-init-pg \
     statefulset/summon-sidecar-pg \
     statefulset/secretless-pg

  echo "Deploying test app backend"
  test_app_pg_docker_image=$(platform_image test-app-pg)
  sed -e "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_docker_image#g" ./$PLATFORM/postgres.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    $cli create -f -
}

###########################
deploy_sidecar_app() {
  $cli delete --ignore-not-found \
    deployment/test-app-summon-sidecar \
    service/test-app-summon-sidecar \
    serviceaccount/test-app-summon-sidecar \
    serviceaccount/oc-test-app-summon-sidecar

  if [ $PLATFORM = 'openshift' ]; then
    oc delete --ignore-not-found deploymentconfig/test-app-summon-sidecar
  fi

  sleep 5

  sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_sidecar_app_docker_image#g" ./$PLATFORM/test-app-summon-sidecar.yml |
    sed -e "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" |
    sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed -e "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    sed -e "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed -e "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONJUR_VERSION }}#'$CONJUR_VERSION'#g" |
    $cli create -f -

  echo "Test app/sidecar deployed."
}

###########################
deploy_init_container_app() {
  $cli delete --ignore-not-found \
    deployment/test-app-summon-init \
    service/test-app-summon-init \
    serviceaccount/test-app-summon-init \
    serviceaccount/oc-test-app-summon-init

  if [ $PLATFORM = 'openshift' ]; then
    oc delete --ignore-not-found deploymentconfig/test-app-summon-init
  fi

  sleep 5

  sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_init_app_docker_image#g" ./$PLATFORM/test-app-summon-init.yml |
    sed -e "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" |
    sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed -e "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    sed -e "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed -e "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONJUR_VERSION }}#'$CONJUR_VERSION'#g" |
    $cli create -f -

  echo "Test app/init-container deployed."
}

###########################
deploy_secretless_app() {
  $cli delete --ignore-not-found \
    deployment/test-app-secretless \
    service/test-app-secretless \
    serviceaccount/test-app-secretless \
    serviceaccount/oc-test-app-secretless \
    configmap/test-app-secretless-config

  if [ $PLATFORM = 'openshift' ]; then
    oc delete --ignore-not-found deploymentconfig/test-app-secretless
  fi

  $cli create configmap test-app-secretless-config \
    --from-file=etc/secretless.yml

  sleep 5

  sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" ./$PLATFORM/test-app-secretless.yml |
    sed -e "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed -e "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed -e "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    $cli create -f -

  echo "Secretless test app deployed."
}

main $@
