#!/bin/bash

set -euo pipefail

# Set the default values of environment variables used by the scripts
CONJUR_VERSION=${CONJUR_VERSION:-$CONJUR_MAJOR_VERSION} # default to CONJUR_MAJOR_VERSION if not set
PLATFORM="${PLATFORM:-kubernetes}"  # default to kubernetes if env var not set

MINIKUBE="${MINIKUBE:-false}"
MINISHIFT="${MINISHIFT:-false}"

LOCAL_AUTHENTICATOR="${LOCAL_AUTHENTICATOR:-false}"
DEPLOY_MASTER_CLUSTER="${DEPLOY_MASTER_CLUSTER:-false}"

DOCKER_EMAIL="${DOCKER_EMAIL:-}"
