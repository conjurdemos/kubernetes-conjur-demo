#!/bin/bash

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

platform_image() {
  if [ $PLATFORM = "openshift" ]; then
    echo "$DOCKER_REGISTRY_PATH/$TEST_APP_NAMESPACE_NAME/$1:$TEST_APP_NAMESPACE_NAME"
  elif ! is_minienv; then
    echo "$DOCKER_REGISTRY_PATH/$1:$CONJUR_NAMESPACE_NAME"
  else
    echo "$1:$CONJUR_NAMESPACE_NAME"
  fi
}

has_namespace() {
  if $cli get namespace  "$1" > /dev/null; then
    true
  else
    false
  fi
}

docker_tag_and_push() {
  if [ $PLATFORM = "kubernetes" ]; then
    docker_tag="$DOCKER_REGISTRY_PATH/$1:$CONJUR_NAMESPACE_NAME"
  else
    docker_tag="$DOCKER_REGISTRY_PATH/$CONJUR_NAMESPACE_NAME/$1:$CONJUR_NAMESPACE_NAME"
  fi

  docker tag $1:$CONJUR_NAMESPACE_NAME $docker_tag
  docker push $docker_tag
}

get_pod_name() {
  local pod_identifier=$1

  # Query to get the pod name, ignoring temp "deploy" pods
  pod_name=$($cli get pods | grep "$pod_identifier" | grep -v "deploy" | awk '{ print $1 }')
  echo "$pod_name"
}

get_master_pod_name() {
  pod_list=$($cli get pods --selector app=conjur-node,role=master --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

get_conjur_cli_pod_name() {
  pod_list=$($cli get pods --selector app=conjur-cli --no-headers | awk '{ print $1 }')
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
      eval $@ > /dev/null && echo 'Success!' && return true
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

function service_ip() {
  local service=$1

  echo "$($cli describe service $service | grep 'LoadBalancer Ingress' |
    awk '{ print $3 }')"
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
