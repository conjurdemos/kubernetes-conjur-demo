#!/usr/bin/env bash

set -eo pipefail

if [ "$CONJUR_APPLIANCE_URL" != "" ]; then
  conjur init -u $CONJUR_APPLIANCE_URL -a $CONJUR_ACCOUNT
fi

# check for unset vars after checking for appliance url
set -u

conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD

readonly POLICY_DIR="/policy"

# NOTE: generated files are prefixed with the test app namespace to allow for parallel CI
readonly POLICY_FILES=(
  "$POLICY_DIR/users.yml"
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.project-authn.yml"
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.cluster-authn-svc.yml"
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.app-identity.yml"
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.authn-any-policy-branch.yml"
  "$POLICY_DIR/app-access.yml"
)

for policy_file in "${POLICY_FILES[@]}"; do
  echo "Loading policy $policy_file..."
  conjur policy load root $policy_file
done

# load secret values for each app
readonly APPS=(
  "test-summon-init-app"
  "test-summon-sidecar-app"
  "test-secretless-app"
)

for app_name in "${APPS[@]}"; do
  echo "Loading secret values for $app_name"
  conjur variable values add "$app_name-db/password" $DB_PASSWORD
  conjur variable values add "$app_name-db/username" "test_app"

  case "${TEST_APP_DATABASE}" in
  postgres)
    PORT=5432
    PROTOCOL=postgresql
    ;;
  mysql)
    PORT=3306
    PROTOCOL=mysql
    ;;
  *)
    echo "Expected TEST_APP_DATABASE to be 'mysql' or 'postgres', got '${TEST_APP_DATABASE}'"
    exit 1
    ;;
  esac
  db_host="$app_name-backend.$TEST_APP_NAMESPACE_NAME.svc.cluster.local"
  db_address="$db_host:$PORT"

  if [[ "$app_name" = "test-secretless-app" ]]; then
    # Secretless doesn't require the full connection URL, just the host/port
    conjur variable values add "$app_name-db/url" "$db_address"
    conjur variable values add "$app_name-db/port" "$PORT"
    conjur variable values add "$app_name-db/host" "$db_host"
  else
    # The authenticator sidecar injects the full pg connection string into the
    # app environment using Summon
    conjur variable values add "$app_name-db/url" "$PROTOCOL://$db_address/test_app"
  fi
done

conjur authn logout
