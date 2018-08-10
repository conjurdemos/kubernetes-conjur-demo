#!/bin/bash  -x
set -euo pipefail

. utils.sh

if [ $PLATFORM = 'openshift' ]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
fi

announce "Building, pushing and Deploying Conjur CLI."

set_namespace $TEST_APP_NAMESPACE_NAME

pushd conjur-cli
  ./build.sh
popd
  
cli_app_image=$(platform_image conjur-cli)
docker tag conjur-cli:$CONJUR_NAMESPACE_NAME $cli_app_image
docker push $cli_app_image

sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" ./$PLATFORM/conjur-cli.yml |
  $cli create -f -

wait_for_it 300 "$cli describe po conjur-cli | grep Status: | grep -c Running"

echo "Conjur CLI is running."





