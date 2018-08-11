#!/bin/bash
set -euo pipefail

. utils.sh

announce "Loading Conjur policy."

pushd policy
  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/cluster-authn-svc-def.template.yml > ./generated/cluster-authn-svc.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/project-authn-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ TEST_APP_NAME }}#$TEST_APP_NAME#g" > ./generated/project-authn.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/app-identity-def.template.yml |
    sed -e "s#{{ TEST_APP_NAME }}#$TEST_APP_NAME#g" > ./generated/app-identity.yml

  sed -e "s#{{ TEST_APP_NAME }}#$TEST_APP_NAME#g" ./templates/app-access-def.template.yml > ./generated/app-access.yml
popd


set_namespace $CONJUR_NAMESPACE_NAME
conjur_cli_pod=$(get_conjur_cli_pod_name)

if [ $PLATFORM = 'kubernetes' ]; then
  kubectl cp ./policy $conjur_cli_pod:/policy
elif [ $PLATFORM = 'openshift' ]; then
  oc rsync ./policy $conjur_cli_pod:/
fi

conjur_url="https://conjur-master.$CONJUR_NAMESPACE_NAME.svc.cluster.local"

if [ $CONJUR_VERSION = '4' ]; then
  $cli exec $conjur_cli_pod -- bash -c "yes yes | conjur init -a $CONJUR_ACCOUNT -h $conjur_url"
  $cli exec $conjur_cli_pod -- touch /opt/conjur/etc/plugins.yml
  $cli exec $conjur_cli_pod -- conjur plugin uninstall policy
  $cli exec $conjur_cli_pod -- conjur plugin install policy
elif [ $CONJUR_VERSION = '5' ]; then
  $cli exec $conjur_cli_pod -- bash -c "yes yes | conjur init -a $CONJUR_ACCOUNT -u $conjur_url"
fi

$cli exec $conjur_cli_pod -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD

POLICY_FILE_LIST=$(cat policies.txt)
for i in $POLICY_FILE_LIST; do
  if [ $CONJUR_VERSION = '4' ]; then
    $cli exec $conjur_cli_pod -- conjur policy load --as-group security_admin $i
  elif [ $CONJUR_VERSION = '5' ]; then
    $cli exec $conjur_cli_pod -- conjur policy load root $i
  fi
done
    
$cli exec $conjur_cli_pod -- rm -rf ./policy

echo "Conjur policy loaded."

password=$(openssl rand -hex 12)

$cli exec $conjur_cli_pod -- conjur variable values add "secrets/db-password" $password

announce "Added DB password value: $password"

$cli exec $conjur_cli_pod -- conjur authn logout

set_namespace $TEST_APP_NAMESPACE_NAME
