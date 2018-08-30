#!/bin/bash -e
docker build -t test-app:$CONJUR_NAMESPACE_NAME .
