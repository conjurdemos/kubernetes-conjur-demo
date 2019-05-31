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
  #deploy_secretless_app
}

###########################
init_registry_creds() {
  if [[ "${PLATFORM}" == "kubernetes" ]] && [[ -n "${DOCKER_EMAIL}" ]]; then
    announce "Creating image pull secret."

    kubectl delete --ignore-not-found secret dockerpullsecret

    kubectl create secret docker-registry dockerpullsecret \
      --docker-server=$DOCKER_REGISTRY_URL \
      --docker-username=$DOCKER_USERNAME \
      --docker-password=$DOCKER_PASSWORD \
      --docker-email=$DOCKER_EMAIL
  elif [[ "$PLATFORM" == "openshift" ]]; then
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

  if [[ "$LOCAL_AUTHENTICATOR" == "true" ]]; then
    authenticator_client_image=$(platform_image conjur-authn-k8s-client)
    secretless_image=$(platform_image secretless-broker)
  else
    authenticator_client_image="cyberark/conjur-kubernetes-authenticator"
    secretless_image="cyberark/secretless-broker"
  fi

  conjur_follower_name=${CONJUR_FOLLOWER_NAME:-conjur-follower}
  conjur_appliance_url=https://$conjur_follower_name.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api
  conjur_authenticator_url=https://$conjur_follower_name.$CONJUR_NAMESPACE_NAME.svc.cluster.local/api/authn-k8s/$AUTHENTICATOR_ID

  conjur_authn_login_prefix=""
  if [[ "$CONJUR_VERSION" == "4" ]]; then
    conjur_authn_login_prefix=$TEST_APP_NAMESPACE_NAME/service_account
  elif [[ "$CONJUR_VERSION" == "5" ]]; then
    conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps/$TEST_APP_NAMESPACE_NAME/service_account
  fi
}

###########################
deploy_app_backend() {
  $cli delete --ignore-not-found \
     service/test-secretless-app-mysql-backend \
     service/test-secretless-app-postgresql-backend \
     statefulset/secretless-pg \
     statefulset/secretless-mysql \
     secret/test-app-backend-certs

  echo "Create secrets for test app postgresql backend"
  $cli --namespace $TEST_APP_NAMESPACE_NAME \
    create secret generic \
    test-app-backend-certs \
    --from-file=server.crt=./etc/ca.pem \
    --from-file=server.key=./etc/ca-key.pem

  echo "Deploying test app backend"
  test_app_pg_docker_image=$(platform_image test-app-pg)

  sed "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_docker_image#g" ./$PLATFORM/tmp.${TEST_APP_NAMESPACE_NAME}.postgres.yml |
    sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    $cli create -f -

  echo "Deploying test app mysql backend"
  test_app_mysql_docker_image="mysql/mysql-server:5.7"

  sed "s#{{ TEST_APP_DATABASE_DOCKER_IMAGE }}#$test_app_mysql_docker_image#g" ./$PLATFORM/tmp.${TEST_APP_NAMESPACE_NAME}.mysql.yml |
    sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    $cli create -f -
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

  sed "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" ./$PLATFORM/test-app-secretless.yml |
    sed "s#{{ SECRETLESS_IMAGE }}#$secretless_image#g" |
    sed "s#{{ SECRETLESS_DB_URL }}#$secretless_db_url#g" |
    sed "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    $cli create -f -

  if [[ "$PLATFORM" == "openshift" ]]; then
    oc expose service test-app-secretless
  fi

  echo "Secretless test app deployed."
}

main $@
