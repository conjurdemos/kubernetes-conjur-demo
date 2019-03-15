#!/bin/bash
set -eo pipefail

. utils.sh

check_env_var "CONJUR_VERSION"
check_env_var "CONJUR_NAMESPACE_NAME"
check_env_var "TEST_APP_NAMESPACE_NAME"
[[ "$PLATFORM" == "kubernetes" ]] && check_env_var "DOCKER_REGISTRY_URL"
check_env_var "DOCKER_REGISTRY_PATH"
check_env_var "CONJUR_ACCOUNT"
check_env_var "CONJUR_ADMIN_PASSWORD"
check_env_var "AUTHENTICATOR_ID"
check_env_var "TEST_APP_DATABASE"
case "${TEST_APP_DATABASE}" in
postgres)
  ;;
mysql)
  ;;
*)
  echo "Expected TEST_APP_DATABASE to be 'mysql' or 'postgres', got '${TEST_APP_DATABASE}'"
  exit 1
  ;;
esac
