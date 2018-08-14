FROM ruby:2.2.9
MAINTAINER CyberArk

#---some useful tools for interactive usage---#
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl

#---install summon and summon-conjur---#
RUN curl -sSL https://raw.githubusercontent.com/cyberark/summon/master/install.sh \
      | env TMPDIR=$(mktemp -d) bash && \
    curl -sSL https://raw.githubusercontent.com/cyberark/summon-conjur/master/install.sh \
      | env TMPDIR=$(mktemp -d) bash
# as per https://github.com/cyberark/summon#linux
# and    https://github.com/cyberark/summon-conjur#install
ENV PATH="/usr/local/lib/summon:${PATH}"
