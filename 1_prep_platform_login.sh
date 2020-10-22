#!/usr/bin/env bash
set -euo pipefail

. utils.sh

if [[ $PLATFORM == openshift ]]; then
  oc login -u $OSHIFT_CLUSTER_ADMIN_USERNAME
fi

