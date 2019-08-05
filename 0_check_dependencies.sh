#!/bin/bash
set -eo pipefail

. utils.sh

check_env_var "CONJUR_VERSION"
check_env_var "CONJUR_NAMESPACE_NAME"
check_env_var "TEST_APP_NAMESPACE_NAME"
if [[ "$PLATFORM" == "kubernetes" ]] && ! is_minienv; then
  check_env_var "DOCKER_REGISTRY_URL"
fi

if ! ( [[ "$PLATFORM" == "kubernetes" ]] && is_minienv ); then
  check_env_var "DOCKER_REGISTRY_PATH"
fi

check_env_var "CONJUR_ACCOUNT"
check_env_var "CONJUR_ADMIN_PASSWORD"
check_env_var "AUTHENTICATOR_ID"
check_env_var "TEST_APP_DATABASE"
ensure_env_database
