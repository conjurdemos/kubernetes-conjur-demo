#!/bin/bash
set -euo pipefail

. utils.sh

if [ $PLATFORM = 'openshift' ]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
fi

announce "Building and pushing test app image."

pushd test_app_api
  ./build.sh
popd

test_app_image=$(platform_image test-app)
docker tag test-app:$CONJUR_NAMESPACE_NAME $test_app_image
docker push $test_app_image
