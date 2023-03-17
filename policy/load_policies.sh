#!/usr/bin/env sh

set -eo

if [ "$CONJUR_APPLIANCE_URL" != "" ]; then
  echo y | conjur init -u $CONJUR_APPLIANCE_URL -a $CONJUR_ACCOUNT --self-signed --force
fi

# check for unset vars after checking for appliance url
set -u

conjur login -i admin -p $CONJUR_ADMIN_PASSWORD

readonly POLICY_DIR="/policy"

# NOTE: generated files are prefixed with the test app namespace to allow for parallel CI
set -- "$POLICY_DIR/users.yml" \
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.project-authn.yml" \
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.cluster-authn-svc.yml" \
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.app-identity.yml" \
  "$POLICY_DIR/generated/$TEST_APP_NAMESPACE_NAME.authn-any-policy-branch.yml" \
  "$POLICY_DIR/app-access.yml"

for policy_file in "$@"; do
  echo "Loading policy $policy_file..."
  conjur policy load -b root -f $policy_file
done

# load secret values for each app
set -- "test-summon-init-app" "test-summon-sidecar-app" "test-secretless-app"

for app_name in "$@"; do
  echo "Loading secret values for $app_name"
  conjur variable set -i "$app_name-db/password" -v $DB_PASSWORD
  conjur variable set -i "$app_name-db/username" -v "test_app"

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

  if [ "$app_name" = "test-secretless-app" ]; then
    # Secretless doesn't require the full connection URL, just the host/port
    conjur variable set -i "$app_name-db/url" -v "$db_address"
    conjur variable set -i "$app_name-db/port" -v "$PORT"
    conjur variable set -i "$app_name-db/host" -v "$db_host"
  else
    # The authenticator sidecar injects the full pg connection string into the
    # app environment using Summon
    conjur variable set -i "$app_name-db/url" -v "$PROTOCOL://$db_address/test_app"
  fi
done

conjur logout
