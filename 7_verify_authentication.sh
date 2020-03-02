#!/usr/bin/env bash
set -euo pipefail

. utils.sh


RETRIES=150
# Seconds
RETRY_WAIT=2

function finish {
  readonly PIDS=(
    "SIDECAR_PORT_FORWARD_PID"
    "INIT_PORT_FORWARD_PID"
    "INIT_WITH_HOST_OUTSIDE_APPS_PORT_FORWARD_PID"
    "SECRETLESS_PORT_FORWARD_PID"
  )

  set +u

  echo -e "\n\nStopping all port-forwarding"
  for pid in "${PIDS[@]}"; do
    if [ -n "${!pid}" ]; then
      # Kill process, and swallow any errors
      kill "${!pid}" > /dev/null 2>&1
    fi
  done
}
trap finish EXIT

announce "Validating that the deployments are functioning as expected."

set_namespace "$TEST_APP_NAMESPACE_NAME"

echo Conjur namespace: $CONJUR_NAMESPACE_NAME
announce "Describing Service Accounts in Conjur Namespace"
$cli describe sa -n $CONJUR_NAMESPACE_NAME
announce "Get OC version"
$cli version
announce "Get users"
$cli get users
announce "Describing rolebinding.rbac test-app-conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME"
$cli describe rolebinding.rbac test-app-conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME
announce "Describing rolebinding test-app-conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME"
$cli describe rolebinding test-app-conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME
announce "Describing DeploymentConfigs in test app namespace"
$cli describe deploymentconfigs

echo "Waiting for pods to become available"

retry_count=0
check_pods(){
  let "retry_count++"
  if [[ $retry_count -eq 20 ]]; then
    follower_pod_name=$($cli get pods -n $CONJUR_NAMESPACE_NAME --selector role=follower --no-headers | awk '{ print $1 }' | head -1)
    announce "Checking for RBAC errors in follower pod logs."
    echo Follower pod: $follower_pod_name
    echo ================================
    $cli logs -n $CONJUR_NAMESPACE_NAME $follower_pod_name | grep RBAC
  else
    echo Retry count: $retry_count
  fi
  pods_ready "test-app-summon-init" &&
  pods_ready "test-app-with-host-outside-apps-branch-summon-init" &&
  pods_ready "test-app-summon-sidecar" &&
  pods_ready "test-app-secretless"
}
bl_retry_constant "${RETRIES}" "${RETRY_WAIT}"  check_pods


$cli describe pod --selector "app=test-app-summon-init"
$cli describe pod --selector "test-app-with-host-outside-apps-branch-summon-init"
$cli describe pod --selector "test-app-summon-sidecar"
$cli describe pod --selector "test-app-secretless"

if [[ "$PLATFORM" == "openshift" ]]; then
  echo "Waiting for deployments to become available"

  check_deployment_status(){
    [[ "$(deployment_status "oc-test-app-summon-init")" == "Complete" ]] &&
    [[ "$(deployment_status "oc-test-app-with-host-outside-apps-branch-summon-init")" == "Complete" ]] &&
    [[ "$(deployment_status "oc-test-app-summon-sidecar")" == "Complete" ]] &&
    [[ "$(deployment_status "oc-test-app-secretless")" == "Complete" ]]
  }
  bl_retry_constant "${RETRIES}" "${RETRY_WAIT}"  check_deployment_status

  echo Deployment Status oc-test-app-summon-init: $(deployment_status "oc-test-app-summon-init")
  echo Deployment Status oc-test-app-with-host-outside: $(deployment_status "oc-test-app-with-host-outside-apps-branch-summon-init")
  echo Deployment Status oc-test-app-summon-sidecar: $(deployment_status "oc-test-app-summon-sidecar")
  echo Deployment Status oc-test-app-secretless: $(deployment_status "oc-test-app-secretless")

  sidecar_pod=$(get_pod_name test-app-summon-sidecar)
  init_pod=$(get_pod_name test-app-summon-init)
  init_pod_with_host_outside_apps=$(get_pod_name test-app-with-host-outside-apps-branch-summon-init)
  secretless_pod=$(get_pod_name test-app-secretless)

  # Routes are defined, but we need to do port-mapping to access them
  oc port-forward "$sidecar_pod" 8081:8080 > /dev/null 2>&1 &
  SIDECAR_PORT_FORWARD_PID=$!
  oc port-forward "$init_pod" 8082:8080 > /dev/null 2>&1 &
  INIT_PORT_FORWARD_PID=$!
  oc port-forward "$secretless_pod" 8083:8080 > /dev/null 2>&1 &
  SECRETLESS_PORT_FORWARD_PID=$!
  oc port-forward "$init_pod_with_host_outside_apps" 8084:8080 > /dev/null 2>&1 &
  INIT_WITH_HOST_OUTSIDE_APPS_PORT_FORWARD_PID=$!

  sidecar_url="localhost:8081"
  init_url="localhost:8082"
  secretless_url="localhost:8083"
  init_url_with_host_outside_apps="localhost:8084"
else
  echo "Waiting for services to become available"
  check_services(){
    [[ -n "$(service_ip "test-app-summon-init")" ]] &&
    [[ -n "$(service_ip "test-app-with-host-outside-apps-branch-summon-init")" ]] &&
    [[ -n "$(service_ip "test-app-summon-sidecar")" ]] &&
    [[ -n "$(service_ip "test-app-secretless")" ]]
  }
  bl_retry_constant "${RETRIES}" "${RETRY_WAIT}"  check_services

  init_url=$(service_ip test-app-summon-init):8080
  init_url_with_host_outside_apps=$(service_ip test-app-with-host-outside-apps-branch-summon-init):8080
  sidecar_url=$(service_ip test-app-summon-sidecar):8080
  secretless_url=$(service_ip test-app-secretless):8080
fi

echo "Waiting for urls to be ready"
check_urls(){
  (
    curl -sS --connect-timeout 3 "$init_url" &&
    curl -sS --connect-timeout 3 "$init_url_with_host_outside_apps" &&
    curl -sS --connect-timeout 3 "$sidecar_url" &&
    curl -sS --connect-timeout 3 "$secretless_url"
  ) > /dev/null
}

bl_retry_constant "${RETRIES}" "${RETRY_WAIT}" check_urls

echo -e "\nAdding entry to the init app\n"
curl \
  -d '{"name": "Mr. Init"}' \
  -H "Content-Type: application/json" \
  "$init_url"/pet

echo -e "Adding entry to the init app with host outside apps\n"
curl \
  -d '{"name": "Mr. Init"}' \
  -H "Content-Type: application/json" \
  "$init_url_with_host_outside_apps"/pet

echo -e "Adding entry to the sidecar app\n"
curl \
  -d '{"name": "Mr. Sidecar"}' \
  -H "Content-Type: application/json" \
  "$sidecar_url"/pet

echo -e "Adding entry to the secretless app\n"
curl \
  -d '{"name": "Mr. Secretless"}' \
  -H "Content-Type: application/json" \
  "$secretless_url"/pet

echo -e "Querying init app\n"
curl "$init_url"/pets

echo -e "\n\nQuerying init app with hosts outside apps\n"
curl "$init_url_with_host_outside_apps"/pets

echo -e "\n\nQuerying sidecar app\n"
curl "$sidecar_url"/pets

echo -e "\n\nQuerying secretless app\n"
curl "$secretless_url"/pets
