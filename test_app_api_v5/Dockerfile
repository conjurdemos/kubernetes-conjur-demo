FROM ruby:2.3

RUN gem install -N activesupport --version 4.2.7.1
RUN gem install -N conjur-api conjur-cli sinatra

COPY test_app.rb usr/src/test_app.rb

ENV PORT 3000

CMD [ "ruby", "/usr/src/test_app.rb" ]
