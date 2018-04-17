#!/bin/bash
set -eou pipefail

. utils.sh

announce "Building and pushing test app image."

pushd test_app/build
  ./build.sh
popd
  
docker_tag_and_push test-app
