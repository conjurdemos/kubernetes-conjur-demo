FROM ubuntu:16.04

RUN apt-get update && apt-get install -y curl vim

RUN curl -o conjur.deb -L https://github.com/conjurinc/cli-ruby/releases/download/v5.4.0/conjur_5.4.0-1_amd64.deb \
  && dpkg -i conjur.deb \
  && rm conjur.deb \
  && curl -LO https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
  && chmod a+x jq-linux64 \
  && mv jq-linux64 /usr/local/bin/jq

RUN mkdir -p /usr/local/lib/summon \
    && mv /etc/vim/vimrc /etc/vim/vimrc.bak

WORKDIR /tmp/

COPY summon-linux-amd64.tar.gz .
COPY summon-conjur-linux-amd64.tar.gz .

RUN tar xzf /tmp/summon-linux-amd64.tar.gz && mv summon /usr/local/bin/
RUN tar xzf /tmp/summon-conjur-linux-amd64.tar.gz && mv summon-conjur /usr/local/lib/summon/

WORKDIR /

COPY copy-summon.sh .
COPY webapp.sh .
COPY secrets.yml .
COPY uid_entrypoint.sh .

RUN chmod g=u /etc/passwd /*.sh
ENTRYPOINT [ "/uid_entrypoint.sh" ]
USER 1001
