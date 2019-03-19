#!/bin/bash
set -euo pipefail

. utils.sh

announce "Generating Conjur policy."

pushd policy
  mkdir -p ./generated

  # NOTE: generated files are prefixed with the test app namespace to allow for parallel CI

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/cluster-authn-svc-def.template.yml > ./generated/$TEST_APP_NAMESPACE_NAME.cluster-authn-svc.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/project-authn-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" > ./generated/$TEST_APP_NAMESPACE_NAME.project-authn.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/app-identity-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" > ./generated/$TEST_APP_NAMESPACE_NAME.app-identity.yml
popd

# Create the random database password
password=$(openssl rand -hex 12)

if [[ "${DEPLOY_MASTER_CLUSTER}" == "true" ]]; then

  announce "Loading Conjur policy."

  set_namespace "$CONJUR_NAMESPACE_NAME"
  conjur_cli_pod=$(get_conjur_cli_pod_name)

  $cli exec $conjur_cli_pod -- rm -rf /policy
  $cli cp ./policy $conjur_cli_pod:/policy

  $cli exec $conjur_cli_pod -- \
    bash -c "
      CONJUR_ADMIN_PASSWORD=${CONJUR_ADMIN_PASSWORD} \
      DB_PASSWORD=${password} \
      TEST_APP_NAMESPACE_NAME=${TEST_APP_NAMESPACE_NAME} \
      TEST_APP_DATABASE=${TEST_APP_DATABASE} \
      CONJUR_VERSION=${CONJUR_VERSION} \
      /policy/load_policies.sh
    "

  $cli exec $conjur_cli_pod -- rm -rf ./policy

  echo "Conjur policy loaded."

  set_namespace "$TEST_APP_NAMESPACE_NAME"
fi

# Set DB password in Kubernetes manifests
# NOTE: generated files are prefixed with the test app namespace to allow for parallel CI
pushd kubernetes
  sed -e "s#{{ TEST_APP_DB_PASSWORD }}#$password#g" ./postgres.template.yml > ./${TEST_APP_NAMESPACE_NAME}.postgres.yml
  sed -e "s#{{ TEST_APP_DB_PASSWORD }}#$password#g" ./mysql.template.yml > ./${TEST_APP_NAMESPACE_NAME}.mysql.yml
popd

# Set DB password in OC manifests
# NOTE: generated files are prefixed with the test app namespace to allow for parallel CI
pushd openshift
  sed -e "s#{{ TEST_APP_DB_PASSWORD }}#$password#g" ./postgres.template.yml > ./${TEST_APP_NAMESPACE_NAME}.postgres.yml
  sed -e "s#{{ TEST_APP_DB_PASSWORD }}#$password#g" ./mysql.template.yml > ./${TEST_APP_NAMESPACE_NAME}.mysql.yml
popd

announce "Added DB password value: $password"
