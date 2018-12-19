#!/bin/bash

. set_env_vars.sh

if [ $PLATFORM = 'kubernetes' ]; then
    cli=kubectl
elif [ $PLATFORM = 'openshift' ]; then
    cli=oc
fi

check_env_var() {
  var_name=$1

  # temporarily turn off checking for unset variables
  set +u

  if [ "${!var_name}" = "" ]; then
    echo "You must set $1 before running these scripts."
    exit 1
  fi

  set -u
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
  elif [ $MINIKUBE != true ]; then
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

get_master_pod_name() {
  pod_list=$($cli get pods -l app=conjur-node,role=master --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

get_conjur_cli_pod_name() {
  pod_list=$($cli get pods -l app=conjur-cli --no-headers | awk '{ print $1 }')
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
      eval $@ > /dev/null && echo 'Success!' && break
      echo -n .
      sleep $spacer
    done

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
  if hash minishift 2>/dev/null; then
    # Check if Minishift is running too
    if [[ $MINIKUBE == false && "$(minishift status | grep Running)" = "" ]]; then
      false
    else
      true
    fi
  else
    if [[ $MINIKUBE == false ]]; then
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
