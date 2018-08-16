FROM ubuntu:16.04

RUN apt-get update && apt-get install -y curl vim

RUN curl -LO https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
  && chmod a+x jq-linux64 \
  && mv jq-linux64 /usr/local/bin/jq

RUN mv /etc/vim/vimrc /etc/vim/vimrc.bak

WORKDIR /

COPY webapp*.sh /
COPY uid_entrypoint.sh /

RUN chmod g=u /etc/passwd /*.sh
ENTRYPOINT [ "/uid_entrypoint.sh" ]
USER 1001
