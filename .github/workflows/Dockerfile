# Copyright (c) 2021 Oracle and/or its affiliates.
FROM ruby:3.0.1-slim

COPY Gemfile /Gemfile
RUN bundle install --without development test
COPY zip_maker.rb /zip_maker.rb

ENTRYPOINT ["ruby", "/zip_maker.rb"]