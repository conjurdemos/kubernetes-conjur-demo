#!/usr/bin/env bash

set -euo pipefail

# Set the default values of environment variables used by the scripts
PLATFORM="${PLATFORM:-kubernetes}"  # default to kubernetes if env var not set
CONJUR_AUTHN_LOGIN_RESOURCE="${CONJUR_AUTHN_LOGIN_RESOURCE:-service_account}" # default to service_account

MINIKUBE="${MINIKUBE:-false}"
MINISHIFT="${MINISHIFT:-false}"

LOCAL_AUTHENTICATOR="${LOCAL_AUTHENTICATOR:-false}"
LOCAL_SECRETLESS_BROKER="${LOCAL_SECRETLESS_BROKER:-false}"
DEPLOY_MASTER_CLUSTER="${DEPLOY_MASTER_CLUSTER:-false}"

DOCKER_EMAIL="${DOCKER_EMAIL:-}"
