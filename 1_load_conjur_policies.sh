#!/bin/bash
set -euo pipefail

. utils.sh

announce "Loading Conjur policy."

set_namespace $CONJUR_NAMESPACE_NAME

conjur_master=$(get_master_pod_name)

# (re)install Conjur policy plugin
$cli exec $conjur_master -- touch /opt/conjur/etc/plugins.yml
$cli exec $conjur_master -- conjur plugin uninstall policy
$cli exec $conjur_master -- conjur plugin install policy

pushd policy
  sed -e "s#{{ AUTHENTICATOR_SERVICE_ID }}#$AUTHENTICATOR_ID#g" ./authn-k8s.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" > ./authn-k8s.yml

  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" ./apps.template.yml > ./apps.yml
popd

if [ $PLATFORM = 'kubernetes' ]; then
    kubectl cp ./policy $conjur_master:/policy
elif [ $PLATFORM = 'openshift' ]; then
    oc rsync ./policy $conjur_master:/
fi

$cli exec $conjur_master -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD
$cli exec $conjur_master -- conjur policy load --as-group security_admin "policy/conjur.yml"

$cli exec $conjur_master -- rm -rf ./policy

echo "Conjur policy loaded."

password=$(openssl rand -hex 12)

$cli exec $conjur_master -- conjur variable values add test-app-db/password $password

announce "Added DB password value: $password"

$cli exec $conjur_master -- conjur authn logout
