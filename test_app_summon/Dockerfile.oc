FROM cyberark/demo-app
ARG namespace
MAINTAINER CyberArk

#---copy summon into image---#
COPY tmp.summon-conjur /usr/local/lib/summon/summon-conjur
COPY tmp.summon /usr/local/bin/summon

#---copy secrets.yml into image---#
COPY tmp.$namespace.secrets.yml /etc/secrets.yml

#---override entrypoint to wrap command with summon---#
ENTRYPOINT [ "summon", "--provider", "summon-conjur", "-f", "/etc/secrets.yml", "java", "-jar", "/app.jar"]
