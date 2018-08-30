#!/bin/bash
set -euo pipefail

. utils.sh

if [ $PLATFORM = 'openshift' ]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
fi

announce "Building and pushing test app images."

# Kubernetes and OpenShift currently run different apps in the demo
if [[ "$PLATFORM" = "kubernetes" ]]; then

  pushd test_app
    docker build -t test-app:$CONJUR_NAMESPACE_NAME .

    test_app_image=$(platform_image test-app)
    docker tag test-app:$CONJUR_NAMESPACE_NAME $test_app_image

    if [[ is_minienv != true ]]; then
      docker push $test_app_image
    fi
  popd

  pushd pg
    docker build -t test-app-pg:$CONJUR_NAMESPACE_NAME .

    test_app_pg_image=$(platform_image test-app-pg)
    docker tag test-app-pg:$CONJUR_NAMESPACE_NAME $test_app_pg_image

    if [[ is_minienv != true ]]; then
      docker push $test_app_pg_image
    fi
  popd

else

  pushd webapp
    ./build.sh
    test_app_image=$(platform_image test-app)
    docker tag test-app:$CONJUR_NAMESPACE_NAME $test_app_image
    if [[ is_minienv != true ]]; then
      docker push $test_app_image
    fi
  popd

fi
