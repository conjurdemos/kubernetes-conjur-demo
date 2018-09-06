#!/bin/bash
set -euo pipefail

. utils.sh

announce "Loading Conjur policy."

pushd policy
  mkdir -p ./generated

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/cluster-authn-svc-def.template.yml > ./generated/cluster-authn-svc.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/project-authn-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" > ./generated/project-authn.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/app-identity-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" > ./generated/app-identity.yml
popd


set_namespace $CONJUR_NAMESPACE_NAME
conjur_cli_pod=$(get_conjur_cli_pod_name)

if [ $PLATFORM = 'kubernetes' ]; then
  kubectl exec $conjur_cli_pod -- rm -rf /policy
  kubectl cp ./policy $conjur_cli_pod:/policy
elif [ $PLATFORM = 'openshift' ]; then
  oc rsync ./policy $conjur_cli_pod:/
fi

$cli exec $conjur_cli_pod -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD

POLICY_FILE_LIST="policy/users.yml
policy/generated/project-authn.yml
policy/generated/cluster-authn-svc.yml
policy/generated/app-identity.yml
policy/app-access.yml"

for i in $POLICY_FILE_LIST; do
  echo "Loading policy $i..."
  if [ $CONJUR_VERSION = '4' ]; then
    $cli exec $conjur_cli_pod -- conjur policy load --as-group security_admin /$i
  elif [ $CONJUR_VERSION = '5' ]; then
    $cli exec $conjur_cli_pod -- conjur policy load root $i
  fi
done
    
$cli exec $conjur_cli_pod -- rm -rf ./policy

echo "Conjur policy loaded."

password=$(openssl rand -hex 12)

# load secret values for each app
readonly APPS=(
  "test-summon-init-app"
  "test-summon-sidecar-app"
  "test-secretless-app"
)

for app_name in "${APPS[@]}"; do
  echo "Loading secret values for $app_name"
  $cli exec $conjur_cli_pod -- conjur variable values add "$app_name-db/password" $password
  $cli exec $conjur_cli_pod -- conjur variable values add "$app_name-db/username" "test_app"

  db_url="$app_name-backend.$TEST_APP_NAMESPACE_NAME.svc.cluster.local:5432/postgres"

  if [[ "$app_name" = "test-secretless-app" ]]; then
    # Secretless doesn't require the full connection URL, just the host/port
    # and an optional database
    $cli exec $conjur_cli_pod -- conjur variable values add "$app_name-db/url" "$db_url"
  else
    $cli exec $conjur_cli_pod -- conjur variable values add "$app_name-db/url" "postgresql://$db_url"
  fi
done

# Set DB password in DB schema
pushd pg
  sed -e "s#{{ TEST_APP_PG_PASSWORD }}#$password#g" ./schema.template.sql > ./schema.sql
popd

announce "Added DB password value: $password"

$cli exec $conjur_cli_pod -- conjur authn logout

set_namespace $TEST_APP_NAMESPACE_NAME
