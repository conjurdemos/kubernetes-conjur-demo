#!/usr/bin/env bash
set -euo pipefail

. utils.sh

if [[ "$PLATFORM" == "openshift" ]]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
fi

announce "Building and pushing test app images."

readonly APPS=(
  "init"
  "sidecar"
)

pushd test_app_summon
  if [[ "$PLATFORM" == "openshift" ]]; then
    echo "Building Summon binaries to include in app image"
    docker build -t test-app-builder -f Dockerfile.builder .

    # retrieve the summon binaries
    id=$(docker create test-app-builder)
    docker cp $id:/usr/local/lib/summon/summon-conjur ./tmp.summon-conjur
    docker cp $id:/usr/local/bin/summon ./tmp.summon
    docker rm --volumes $id
  fi


  for app_type in "${APPS[@]}"; do
    # prep secrets.yml
    # NOTE: generated files are prefixed with the test app namespace to allow for parallel CI
    sed "s#{{ TEST_APP_NAME }}#test-summon-$app_type-app#g" ./secrets.template.yml > "tmp.$TEST_APP_NAMESPACE_NAME.secrets.yml"

    dockerfile="Dockerfile"
    if [[ "$PLATFORM" == "openshift" ]]; then
      dockerfile="Dockerfile.oc"
    fi

    echo "Building test app image"
    docker build \
      --build-arg namespace=$TEST_APP_NAMESPACE_NAME \
      --tag test-app:$CONJUR_NAMESPACE_NAME \
      --file $dockerfile .

    test_app_image=$(platform_image_for_push "test-$app_type-app")
    docker tag test-app:$CONJUR_NAMESPACE_NAME $test_app_image

    if ! is_minienv; then
      docker push $test_app_image
    fi
  done
popd

# If in Kubernetes, build custom pg image
if [[ "$PLATFORM" != "openshift" ]]; then
  pushd pg
    docker build -t test-app-pg:$CONJUR_NAMESPACE_NAME .
    test_app_pg_image=$(platform_image_for_push test-app-pg)
    docker tag test-app-pg:$CONJUR_NAMESPACE_NAME $test_app_pg_image

    if ! is_minienv; then
      docker push $test_app_pg_image
    fi
  popd
else
  # If in Openshift, build and store mysql in openshift registry to circumvent
  # rate-limiting when pulling from docker-hub.
  docker pull centos/mysql-57-centos7
  docker tag centos/mysql-57-centos7 $(platform_image_for_push mysql-57-centos7)

  docker pull centos/mysql-80-centos7:latest
  docker tag centos/mysql-80-centos7:latest $(platform_image_for_push mysql-80-centos7)

  if ! is_minienv; then
    docker push $(platform_image_for_push mysql-57-centos7)
    docker push $(platform_image_for_push mysql-80-centos7)
  fi
fi

if [[ "$LOCAL_AUTHENTICATOR" == "true" ]]; then
  # Re-tag the locally-built conjur-authn-k8s-client:dev image
  authn_image=$(platform_image_for_push conjur-authn-k8s-client)
  docker tag conjur-authn-k8s-client:dev $authn_image

  # Re-tag the locally-built secretless-broker:latest image
  secretless_image=$(platform_image_for_push secretless-broker)
  docker tag secretless-broker:latest $secretless_image

  if ! is_minienv; then
    docker push $authn_image
    docker push $secretless_image
  fi
fi
