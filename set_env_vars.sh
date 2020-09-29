#!/usr/bin/env bash

# Set the default values of environment variables used by the scripts
PLATFORM="${PLATFORM:-kubernetes}"  # default to kubernetes if env var not set
CONJUR_AUTHN_LOGIN_RESOURCE="${CONJUR_AUTHN_LOGIN_RESOURCE:-service_account}" # default to service_account

CONJUR_VERSION="${CONJUR_VERSION:-5}"

MINIKUBE="${MINIKUBE:-false}"
MINISHIFT="${MINISHIFT:-false}"

LOCAL_AUTHENTICATOR="${LOCAL_AUTHENTICATOR:-false}"
DEPLOY_MASTER_CLUSTER="${DEPLOY_MASTER_CLUSTER:-false}"
 
ANNOTATION_BASED_AUTHN="${ANNOTATION_BASED_AUTHN:-false}"
CONJUR_OSS_HELM_INSTALLED="${CONJUR_OSS_HELM_INSTALLED:-false}"
TEST_APP_NODEPORT_SVCS="${TEST_APP_NODEPORT_SVCS:-false}"

DOCKER_EMAIL="${DOCKER_EMAIL:-}"
