#!/usr/bin/env bash
set -euo pipefail

. utils.sh

announce "Creating Test App namespace."

set_namespace default

if has_namespace "$TEST_APP_NAMESPACE_NAME"; then
  echo "Namespace '$TEST_APP_NAMESPACE_NAME' exists, not going to create it."
  set_namespace $TEST_APP_NAMESPACE_NAME
else
  echo "Creating '$TEST_APP_NAMESPACE_NAME' namespace."

  if [ $PLATFORM = 'kubernetes' ]; then
    $cli create namespace $TEST_APP_NAMESPACE_NAME
  elif [ $PLATFORM = 'openshift' ]; then
    $cli new-project $TEST_APP_NAMESPACE_NAME
  fi

  set_namespace $TEST_APP_NAMESPACE_NAME
fi

$cli delete --ignore-not-found rolebinding test-app-conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME

if [[ "$CONJUR_OSS_HELM_INSTALLED" == "true" ]]; then
  conjur_authn_cluster_role="$HELM_RELEASE-conjur-authenticator"
else
  conjur_authn_cluster_role="conjur-authenticator-$CONJUR_NAMESPACE_NAME"
fi
sed "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" ./$PLATFORM/test-app-conjur-authenticator-role-binding.yml |
  sed "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" |
  sed "s#{{ CONJUR_AUTHN_CLUSTER_ROLE }}#$conjur_authn_cluster_role#g" |
  sed "s#{{ CONJUR_SERVICE_ACCOUNT }}#$(conjur_service_account)#g" |
  $cli create -f -

if [[ $PLATFORM == openshift ]]; then
  # add permissions for Conjur admin user
  oc adm policy add-role-to-user system:registry $OSHIFT_CONJUR_ADMIN_USERNAME
  oc adm policy add-role-to-user system:image-builder $OSHIFT_CONJUR_ADMIN_USERNAME

  oc adm policy add-role-to-user admin $OSHIFT_CONJUR_ADMIN_USERNAME -n default
  oc adm policy add-role-to-user admin $OSHIFT_CONJUR_ADMIN_USERNAME -n $TEST_APP_NAMESPACE_NAME
  echo "Logging in as Conjur Openshift admin. Provide password as needed."
  oc login -u $OSHIFT_CONJUR_ADMIN_USERNAME -p $OPENSHIFT_PASSWORD
fi
