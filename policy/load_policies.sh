#!/bin/bash

set -eo pipefail

if [ "$CONJUR_APPLIANCE_URL" != "" ]; then
  conjur init -u $CONJUR_APPLIANCE_URL -a $CONJUR_ACCOUNT
fi

# check for unset vars after checking for appliance url
set -u

conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD

readonly POLICY_FILES=(
  "policy/users.yml"
  "policy/generated/project-authn.yml"
  "policy/generated/cluster-authn-svc.yml"
  "policy/generated/app-identity.yml"
  "policy/app-access.yml"
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
  "test-summon-init-app"
  "test-summon-sidecar-app"
  "test-secretless-app"
)

for app_name in "${APPS[@]}"; do
  echo "Loading secret values for $app_name"
  conjur variable values add "$app_name-db/password" $DB_PASSWORD
  conjur variable values add "$app_name-db/username" "test_app"

  db_url="$app_name-backend.$TEST_APP_NAMESPACE_NAME.svc.cluster.local:5432/postgres"

  if [[ "$app_name" = "test-secretless-app" ]]; then
    # Secretless doesn't require the full connection URL, just the host/port
    # and an optional database
    conjur variable values add "$app_name-db/url" "$db_url"
  else
    conjur variable values add "$app_name-db/url" "postgresql://$db_url"
  fi
done

conjur authn logout
