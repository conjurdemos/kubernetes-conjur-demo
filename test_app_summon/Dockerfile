FROM ruby:2.2.9 as test-app-builder
MAINTAINER CyberArk
LABEL builder="test-app-builder"

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

# ============= MAIN CONTAINER ============== #

FROM cyberark/demo-app
MAINTAINER CyberArk

#---copy summon into image---#
COPY --from=test-app-builder /usr/local/lib/summon /usr/local/lib/summon
COPY --from=test-app-builder /usr/local/bin/summon /usr/local/bin/summon

#---copy secrets.yml into image---#
COPY secrets.yml /etc/secrets.yml

#---override entrypoint to wrap command with summon---#
ENTRYPOINT [ "summon", "--provider", "summon-conjur", "-f", "/etc/secrets.yml", "java", "-jar", "/app.jar"]
