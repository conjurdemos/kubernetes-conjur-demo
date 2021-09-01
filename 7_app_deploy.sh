#!/usr/bin/env bash
set -eo pipefail

. utils.sh

main() {
  announce "Deploying test apps for $TEST_APP_NAMESPACE_NAME."

  URLENCODED_AUTHN_ID=$(urlencode $AUTHENTICATOR_ID)

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
  deploy_init_container_app_with_host_outside_apps
}

###########################
init_registry_creds() {
  if [[ "${PLATFORM}" == "kubernetes" ]] && [[ -n "${DOCKER_EMAIL}" ]]; then
    announce "Creating image pull secret."

    kubectl delete --ignore-not-found secret dockerpullsecret

    kubectl create secret docker-registry dockerpullsecret \
      --docker-server=${PULL_DOCKER_REGISTRY_URL} \
      --docker-username=$DOCKER_USERNAME \
      --docker-password=$DOCKER_PASSWORD \
      --docker-email=$DOCKER_EMAIL
  elif [[ "$PLATFORM" == "openshift" ]]; then
    announce "Creating image pull secret."
    
    $cli delete --ignore-not-found secrets dockerpullsecret

    $cli create secret docker-registry dockerpullsecret \
        --docker-server=${PULL_DOCKER_REGISTRY_URL} \
        --docker-username=_ \
        --docker-password=$($cli whoami -t) \
        --docker-email=_
    $cli secrets link default dockerpullsecret --for=pull
  fi
}

###########################
init_connection_specs() {
  test_sidecar_app_docker_image=$(platform_image_for_pull test-sidecar-app)
  test_init_app_docker_image=$(platform_image_for_pull test-init-app)

  if [[ "$LOCAL_AUTHENTICATOR" == "true" ]]; then
    authenticator_client_image=$(platform_image_for_pull conjur-authn-k8s-client)
    secretless_image=$(platform_image_for_pull secretless-broker)
  else
    authenticator_client_image="cyberark/conjur-authn-k8s-client"
    secretless_image="docker.io/cyberark/secretless-broker"
  fi

  if [[ "$CONJUR_OSS_HELM_INSTALLED" == "true" ]]; then
    conjur_appliance_url=${CONJUR_APPLIANCE_URL:-https://conjur-oss.$CONJUR_NAMESPACE_NAME.svc.cluster.local}
  else
    conjur_follower_name=${CONJUR_FOLLOWER_NAME:-conjur-follower}
    conjur_appliance_url=https://$conjur_follower_name.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api
  fi
  conjur_authenticator_url="$conjur_appliance_url/authn-k8s/$URLENCODED_AUTHN_ID"

  if [[ "$ANNOTATION_BASED_AUTHN" == "true" ]]; then
    # For annotation-based Kubernetes authentication, the host ID to be used
    # for authenticating is an application name.
    conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps
  else
    # For host-ID-based Kubernetes authentication, the host ID to be used
    # for authenticating is in the form:
    #   <namespace-name>/<kubernetes-resource>/<resource-name>
    conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps/$TEST_APP_NAMESPACE_NAME/$CONJUR_AUTHN_LOGIN_RESOURCE
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
     statefulset/secretless-pg \
     statefulset/summon-init-mysql \
     statefulset/summon-sidecar-mysql \
     statefulset/secretless-mysql \
     secret/test-app-backend-certs

  ensure_env_database
  case "${TEST_APP_DATABASE}" in
  postgres)
    echo "Create secrets for test app backend"
    $cli --namespace $TEST_APP_NAMESPACE_NAME \
      create secret generic \
      test-app-backend-certs \
      --from-file=server.crt=./etc/ca.pem \
      --from-file=server.key=./etc/ca-key.pem

    echo "Deploying test app backend"

    test_app_pg_docker_image=$(platform_image_for_pull test-app-pg)

    sed "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_docker_image#g" ./$PLATFORM/tmp.${TEST_APP_NAMESPACE_NAME}.postgres.yml |
      sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
      sed "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
      $cli create -f -
    ;;
  mysql)
    echo "Deploying test app backend"
    
    # See the ./${PLATFORM}/mysql.template.yml file for details about
    # differing mysql versions (for specifically openshift)

    if [[ "${PLATFORM}" == "openshift" ]]; then
      test_summon_mysql_image=$(platform_image_for_pull mysql-80-centos7)
      test_secretless_mysql_image=$(platform_image_for_pull mysql-57-centos7)
    else
      test_summon_mysql_image="mysql/mysql-server:5.7"
      test_secretless_mysql_image=$test_summon_mysql_image
    fi

    sed -e "s#{{ TEST_SUMMON_MYSQL_IMAGE }}#$test_summon_mysql_image#g" \
      -e "s#{{ TEST_SECRETLESS_MYSQL_IMAGE }}#$test_secretless_mysql_image#g" \
      ./$PLATFORM/tmp.${TEST_APP_NAMESPACE_NAME}.mysql.yml |
      sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
      sed "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
      $cli create -f -
    ;;
  esac

}

###########################
deploy_sidecar_app() {
  $cli delete --ignore-not-found \
    deployment/test-app-summon-sidecar \
    service/test-app-summon-sidecar \
    serviceaccount/test-app-summon-sidecar \
    serviceaccount/oc-test-app-summon-sidecar

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc delete --ignore-not-found \
      deploymentconfig/test-app-summon-sidecar \
      route/test-app-summon-sidecar
  fi

  sleep 5

  sed "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_sidecar_app_docker_image#g" ./$PLATFORM/test-app-summon-sidecar.yml |
    sed "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    sed "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ SERVICE_TYPE }}#$(app_service_type)#g" |
    $cli create -f -

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc expose service test-app-summon-sidecar
  fi

  echo "Test app/sidecar deployed."
}

###########################
deploy_init_container_app() {
  $cli delete --ignore-not-found \
    deployment/test-app-summon-init \
    service/test-app-summon-init \
    serviceaccount/test-app-summon-init \
    serviceaccount/oc-test-app-summon-init

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc delete --ignore-not-found \
      deploymentconfig/test-app-summon-init \
      route/test-app-summon-init
  fi

  sleep 5

  sed "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_init_app_docker_image#g" ./$PLATFORM/test-app-summon-init.yml |
    sed "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    sed "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ SERVICE_TYPE }}#$(app_service_type)#g" |
    $cli create -f -

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc expose service test-app-summon-init
  fi

  echo "Test app/init-container deployed."
}

###########################
deploy_init_container_app_with_host_outside_apps() {
  $cli delete --ignore-not-found \
    deployment/test-app-with-outside-host-summon-init \
    service/test-app-with-outside-host-summon-init \
    serviceaccount/test-app-with-outside-host-summon-init \
    serviceaccount/oc-test-app-with-outside-host-summon-init

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc delete --ignore-not-found \
      deploymentconfig/test-app-with-outside-host-summon-init \
      route/test-app-with-outside-host-summon-init
  fi

  sleep 5

  conjur_authn_login="host/some-apps/$TEST_APP_NAMESPACE_NAME/*/*"

  sed "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_init_app_docker_image#g" ./$PLATFORM/test-app-with-outside-host-summon-init.yml |
    sed "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed "s#{{ CONJUR_AUTHN_LOGIN }}#$conjur_authn_login#g" |
    sed "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    sed "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ SERVICE_TYPE }}#$(app_service_type)#g" |
    $cli create -f -

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc expose service test-app-with-outside-host-summon-init
  fi

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

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc delete --ignore-not-found \
      deploymentconfig/test-app-secretless \
      route/test-app-secretless
  fi

  $cli create configmap test-app-secretless-config \
    --from-file=etc/secretless.yml

  sleep 5

  ensure_env_database
  case "${TEST_APP_DATABASE}" in
  postgres)
    PORT=5432
    PROTOCOL=postgresql
    ;;
  mysql)
    PORT=3306
    PROTOCOL=mysql
    ;;
  esac
  secretless_db_url="$PROTOCOL://localhost:$PORT/test_app"

  sed "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" ./$PLATFORM/test-app-secretless.yml |
    sed "s#{{ SECRETLESS_IMAGE }}#$secretless_image#g" |
    sed "s#{{ SECRETLESS_DB_URL }}#$secretless_db_url#g" |
    sed "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    sed "s#{{ SERVICE_TYPE }}#$(app_service_type)#g" |
    $cli create -f -

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc expose service test-app-secretless
  fi

  echo "Secretless test app deployed."
}

main $@
