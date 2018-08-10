#!/bin/bash -e

if [[ ! -f summon-linux-amd64.tar.gz ]]; then
	curl -LO https://github.com/cyberark/summon/releases/download/v0.6.5/summon-linux-amd64.tar.gz
fi
if [[ ! -f summon-conjur-linux-amd64.tar.gz ]]; then
	curl -LO https://github.com/cyberark/summon-conjur/releases/download/v0.4.0/summon-conjur-linux-amd64.tar.gz
fi

docker build -t webapp:$TEST_APP_NAMESPACE_NAME .
