#!/usr/bin/env bash

set -euo pipefail

# Set the default values of environment variables used by the scripts
PLATFORM="${PLATFORM:-kubernetes}"  # default to kubernetes if env var not set

MINIKUBE="${MINIKUBE:-false}"
MINISHIFT="${MINISHIFT:-false}"

LOCAL_AUTHENTICATOR="${LOCAL_AUTHENTICATOR:-false}"
DEPLOY_MASTER_CLUSTER="${DEPLOY_MASTER_CLUSTER:-false}"

DOCKER_EMAIL="${DOCKER_EMAIL:-}"
