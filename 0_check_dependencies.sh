#!/bin/bash
set -eo pipefail

. utils.sh

check_env_var "CONJUR_VERSION"
check_env_var "CONJUR_NAMESPACE_NAME"
check_env_var "TEST_APP_NAMESPACE_NAME"

if [[ "$PLATFORM" == "kubernetes" ]]; then
  check_env_var "DOCKER_REGISTRY_URL"
fi

check_env_var "DOCKER_REGISTRY_PATH"
check_env_var "CONJUR_ACCOUNT"
check_env_var "CONJUR_ADMIN_PASSWORD"
check_env_var "AUTHENTICATOR_ID"
check_env_var "TEST_APP_DATABASE"

ensure_env_database

export DEPLOY_MASTER_CLUSTER="${DEPLOY_MASTER_CLUSTER:-false}"
if [[ "$DEPLOY_MASTER_CLUSTER" != "true" ]]; then
  error_message="Manual policy creation/loading must be done before running './start' when "
  error_message+="not deploying a master cluster!"
  check_file_exists "./$PLATFORM/tmp.${TEST_APP_NAMESPACE_NAME}.postgres.yml" "${error_message}"
  check_file_exists "./$PLATFORM/tmp.${TEST_APP_NAMESPACE_NAME}.mysql.yml" "${error_message}"
fi
