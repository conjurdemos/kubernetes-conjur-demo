#!/bin/bash
set -euo pipefail

. utils.sh

announce "Building and pushing test app image."

pushd test_app
  ./build.sh
popd
  
docker_tag_and_push test-app
