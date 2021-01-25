#!/usr/bin/env bash

. set_env_vars.sh

if [ $PLATFORM = 'kubernetes' ]; then
    cli=kubectl
elif [ $PLATFORM = 'openshift' ]; then
    cli=oc
fi

init_bash_lib() {
  git submodule update --init --recursive
  bash_lib="$(dirname "${BASH_SOURCE[0]}")/bash-lib"
  . "${bash_lib}/init"
}

check_env_var() {
  if [[ -z "${!1+x}" ]]; then
# where ${var+x} is a parameter expansion which evaluates to nothing if var is unset, and substitutes the string x otherwise.
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash/13864829#13864829
    echo "You must set $1 before running these scripts."
    exit 1
  fi
}

ensure_env_database() {
  local valid_dbs=(
  'postgres'
  'mysql'
  )

  if ! echo "${valid_dbs[@]}" | grep -Eq "\b${TEST_APP_DATABASE}\b"; then
    printf "TEST_APP_DATABASE value not found in valid_dbs: '%s'\n" "${TEST_APP_DATABASE}"
    printf "valid_dbs:\n"
    printf "'%s'\n" "${valid_dbs[@]}"
    exit 1
  fi
}

announce() {
  echo "++++++++++++++++++++++++++++++++++++++"
  echo ""
  echo "$@"
  echo ""
  echo "++++++++++++++++++++++++++++++++++++++"
}

platform_image_for_pull() {
  if [[ ${PLATFORM} = "openshift" ]]; then
    echo "${PULL_DOCKER_REGISTRY_PATH}/$TEST_APP_NAMESPACE_NAME/$1:$TEST_APP_NAMESPACE_NAME"
  elif is_minienv; then
    echo "$1:$CONJUR_NAMESPACE_NAME"
  elif [[ "$USE_DOCKER_LOCAL_REGISTRY" = "true" ]]; then
    echo "${PULL_DOCKER_REGISTRY_URL}/$1:$CONJUR_NAMESPACE_NAME"
  else
    echo "${PULL_DOCKER_REGISTRY_PATH}/$1:$CONJUR_NAMESPACE_NAME"
  fi
}

platform_image_for_push() {
  if [[ ${PLATFORM} = "openshift" ]]; then
    echo "${DOCKER_REGISTRY_PATH}/$TEST_APP_NAMESPACE_NAME/$1:$TEST_APP_NAMESPACE_NAME"
  elif is_minienv; then
    echo "$1:$CONJUR_NAMESPACE_NAME"
  elif [[ "$USE_DOCKER_LOCAL_REGISTRY" = "true" ]]; then
    echo "${DOCKER_REGISTRY_URL}/$1:$CONJUR_NAMESPACE_NAME"
  else
    echo "${DOCKER_REGISTRY_PATH}/$1:$CONJUR_NAMESPACE_NAME"
  fi
}

has_namespace() {
  if $cli get namespace  "$1" &>/dev/null; then
    true
  else
    false
  fi
}

get_pod_name() {
  local pod_identifier=$1

  # Query to get the pod name, ignoring temp "deploy" pods
  pod_name=$($cli get pods | grep "$pod_identifier" | grep -v "deploy" | awk '{ print $1 }')
  echo "$pod_name"
}

get_pods() {
  $cli get pods --selector "$1" --no-headers | awk '{ print $1 }'
}

get_nodeport(){
  svc_name="$1"
  echo "$(kubectl get svc $svc_name -o jsonpath='{.spec.ports[0].nodePort}')"
}

app_service_type() {
  if [[ "$TEST_APP_LOADBALANCER_SVCS" == "true" ]]; then
    echo "LoadBalancer"
  else
    echo "NodePort"
  fi
}

get_master_pod_name() {
  if [[ "$CONJUR_OSS_HELM_INSTALLED" == "true" ]]; then
    pod_list=$(get_pods "app=conjur-oss")
  else
    pod_list=$(get_pods "app=conjur-node,role=master")
  fi
  echo $pod_list | awk '{print $1}'
}

get_conjur_cli_pod_name() {
  pod_list=$($cli get pods -n "$CONJUR_NAMESPACE_NAME" --selector app=conjur-cli --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

run_conjur_cmd_as_admin() {
  local command=$(cat $@)

  conjur authn logout > /dev/null
  conjur authn login -u admin -p "$CONJUR_ADMIN_PASSWORD" > /dev/null

  local output=$(eval "$command")

  conjur authn logout > /dev/null
  echo "$output"
}

conjur_service_account() {
  if [[ "$CONJUR_OSS_HELM_INSTALLED" == "true" ]]; then
    echo "conjur-oss"
  else
    echo "conjur-cluster"
  fi
}

set_namespace() {
  if [[ $# != 1 ]]; then
    printf "Error in %s/%s - expecting 1 arg.\n" $(pwd) $0
    exit -1
  fi

  $cli config set-context $($cli config current-context) --namespace="$1" > /dev/null
}

load_policy() {
  local POLICY_FILE=$1

  run_conjur_cmd_as_admin <<CMD
conjur policy load --as-group security_admin "policy/$POLICY_FILE"
CMD
}

rotate_host_api_key() {
  local host=$1

  run_conjur_cmd_as_admin <<CMD
conjur host rotate_api_key -h $host
CMD
}

function wait_for_it() {
  local timeout=$1
  local spacer=2
  shift

  if ! [ $timeout = '-1' ]; then
    local times_to_run=$((timeout / spacer))

    echo "Waiting for '$@' up to $timeout s"
    for i in $(seq $times_to_run); do
      eval $@ > /dev/null && echo 'Success!' && return 0
      echo -n .
      sleep $spacer
    done

    # Last run evaluated. If this fails we return an error exit code to caller
    eval $@
  else
    echo "Waiting for '$@' forever"

    while ! eval $@ > /dev/null; do
      echo -n .
      sleep $spacer
    done
    echo 'Success!'
  fi
}

function is_minienv() {
  MINI_ENV="${MINI_ENV:-false}"

  if hash minishift 2>/dev/null; then
    # Check if Minishift is running too
    if [[ "$MINI_ENV" == "false" ]] && [[ "$(minishift status | grep Running)" = "" ]]; then
      false
    else
      true
    fi
  else
    if [[ "$MINI_ENV" == "false" ]]; then
      false
    else
      true
    fi
  fi
}

function external_ip() {
  local service=$1

  echo "$($cli get svc $service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
}

function deployment_status() {
  local deployment=$1

  echo "$($cli describe deploymentconfig $deployment | awk '/^\tStatus:/' |
    awk '{ print $2 }')"
}

function pods_ready() {
  local app_label=$1

  $cli describe pod --selector "app=$app_label" | awk '/Ready/{if ($2 != "True") exit 1}'
}

function urlencode() {
  # urlencode <string>

  # Run as a subshell so that we can indiscriminately set LC_COLLATE
  (
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
      local c="${1:i:1}"
      case $c in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%%%02X' "'$c" ;;
      esac
    done
  )
}

function dump_kubernetes_resources() {
  echo "Status of pods in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME pods
  echo "Display pods in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME pods -o yaml
  echo "Describe pods in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli describe -n $TEST_APP_NAMESPACE_NAME pods
  echo "Services:in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME svc
  echo "ServiceAccounts:in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME serviceaccounts
  echo "Deployments in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME deployments
  if [[ "$PLATFORM" == "openshift" ]]; then
    echo "DeploymentConfigs in namespace $TEST_APP_NAMESPACE_NAME:"
    $cli get -n $TEST_APP_NAMESPACE_NAME deploymentconfigs
  fi
  echo "Roles in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME roles
  echo "RoleBindings in namespace $TEST_APP_NAMESPACE_NAME:"
  $cli get -n $TEST_APP_NAMESPACE_NAME rolebindings
  echo "ClusterRoles in the cluster:"
  $cli get clusterroles
  echo "ClusterRoleBindings in the cluster:"
  $cli get clusterrolebindings
}

function dump_authentication_policy {
  announce "Authentication policy:"
  cat policy/generated/$TEST_APP_NAMESPACE_NAME.project-authn.yml
}
