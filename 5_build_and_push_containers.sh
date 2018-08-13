#!/bin/bash
set -euo pipefail

. utils.sh

if [ $PLATFORM = 'openshift' ]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
fi

announce "Building and pushing test app image."

pushd $TEST_APP_NAME
  ./build.sh
popd

test_app_image=$(platform_image $TEST_APP_NAME)
docker tag $TEST_APP_NAME:$TEST_APP_NAMESPACE_NAME $test_app_image
if [[ $MINIKUBE != true ]]; then
  docker push $test_app_image
fi
