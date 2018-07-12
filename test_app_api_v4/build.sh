#!/bin/bash
set -euo pipefail

docker build -t test-app:$CONJUR_NAMESPACE_NAME .
