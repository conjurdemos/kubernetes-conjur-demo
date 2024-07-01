FROM alpine
MAINTAINER CyberArk

#---some useful tools for interactive usage---#
RUN apk add --no-cache curl bash

#---install summon and summon-conjur---#
RUN curl -sSL https://raw.githubusercontent.com/cyberark/summon/main/install.sh \
      | env TMPDIR=$(mktemp -d) bash && \
    curl -sSL https://raw.githubusercontent.com/cyberark/summon-conjur/main/install.sh \
      | env TMPDIR=$(mktemp -d) bash
# as per https://github.com/cyberark/summon#linux
# and    https://github.com/cyberark/summon-conjur#install
ENV PATH="/usr/local/lib/summon:${PATH}"
