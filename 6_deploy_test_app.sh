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

  # The Kubernetes app has a PG backend that also needs to be deployed
  if [[ "$PLATFORM" = "kubernetes" ]]; then
    deploy_app_backend
  fi

  deploy_sidecar_app
  deploy_init_container_app
  sleep 10  # allow time for containers to initialize
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
  test_app_docker_image=$(platform_image test-app)

  conjur_appliance_url=https://conjur-follower.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api
  conjur_authenticator_url=https://conjur-follower.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api/authn-k8s/$AUTHENTICATOR_ID

  conjur_authn_login_prefix=""
  if [ $PLATFORM == kubernetes ]; then
    if [ $CONJUR_VERSION = '4' ]; then
      conjur_authn_login_prefix=$TEST_APP_NAMESPACE_NAME/service_account
    elif [ $CONJUR_VERSION = '5' ]; then
      conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps/$TEST_APP_NAMESPACE_NAME/service_account
    fi
  fi
}

###########################
deploy_app_backend() {
  $cli delete --ignore-not-found \
     service/test-app-backend \
     statefulset/pg

  echo "Deploying test app backend"
  test_app_pg_docker_image=$(platform_image test-app-pg)
  sed -e "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_docker_image#g" ./$PLATFORM/postgres.yml |
    $cli create -f -
}

###########################
deploy_sidecar_app() {
  $cli delete --ignore-not-found \
    deployment/test-app-summon-sidecar \
    service/test-app-summon-sidecar \
    serviceaccount/test-app-summon-sidecar

  if [ $PLATFORM = 'openshift' ]; then
    oc delete --ignore-not-found deploymentconfig/test-app-summon-sidecar
  fi

  sleep 5

  sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_docker_image#g" ./$PLATFORM/test-app-summon-sidecar.yml |
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
    serviceaccount/test-app-summon-init

  if [ $PLATFORM = 'openshift' ]; then
    oc delete --ignore-not-found deploymentconfig/test-app-summon-init
  fi

  sleep 5

  sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_docker_image#g" ./$PLATFORM/test-app-summon-init.yml |
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

main $@
