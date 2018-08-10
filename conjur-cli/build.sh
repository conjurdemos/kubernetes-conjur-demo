#!/bin/bash -e
sed -e "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" Dockerfile.template > Dockerfile
docker build -t conjur-cli:$CONJUR_NAMESPACE_NAME .
rm Dockerfile
