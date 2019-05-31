#!/bin/bash

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
  "$POLICY_DIR/app-access.yml"
)

for policy_file in "${POLICY_FILES[@]}"; do
  echo "Loading policy $policy_file..."
  if [[ "$CONJUR_VERSION" == "4" ]]; then
    conjur policy load --as-group security_admin $policy_file
  elif [[ "$CONJUR_VERSION" == "5" ]]; then
    conjur policy load root $policy_file
  fi
done

# load secret values for each app
readonly APPS=(
  "test-secretless-app"
)

readonly TEST_APP_DATABASE=(
  "postgresql"
  "mysql"
)

for app_name in "${APPS[@]}"; do
  for database in "${TEST_APP_DATABASE[@]}"; do
    echo "Loading secret values for $app_name and $database db"
    conjur variable values add "$app_name-$database-db/password" $DB_PASSWORD
    conjur variable values add "$app_name-$database-db/username" "test_app"

    if [[ "$database" = "postgresql" ]]; then
      PORT=5432
    elif [[ "$database" = "mysql" ]]; then
      PORT=3306
    fi


    db_host="$app_name-backend.$TEST_APP_NAMESPACE_NAME.svc.cluster.local"
    db_url="$db_host:$PORT/test_app"

    if [[ "$app_name" = "test-secretless-app" ]]; then
      # Secretless doesn't require the full connection URL, just the host/port
      # and an optional database
      conjur variable values add "$app_name-db/url" "$db_url"
      conjur variable values add "$app_name-db/port" "$PORT"
      conjur variable values add "$app_name-db/host" "$db_host"
    else
      conjur variable values add "$app_name-db/url" "$database://$db_url"
    fi
  done
done

conjur authn logout
