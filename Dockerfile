# syntax=docker/dockerfile:1

# Base image
FROM ruby:3.2.3-alpine as base

ENV BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_DEPLOYMENT="1" \
    RAILS_ENV="production"

# Build stage
FROM base as build

WORKDIR /app
COPY ./Gemfile /app/Gemfile
COPY ./Gemfile.lock /app/Gemfile.lock

RUN apk add --no-cache \
  git \
  bash \
  build-base \
  libxml2-dev \
  libxslt-dev \
  tzdata \
  openssl \
  postgresql-dev \
  libc6-compat

RUN bundle install --jobs 4 --retry 5 && \
  chmod -R a+r /usr/local/bundle

# Final stage
FROM base
LABEL maintainer="keygen.sh <oss@keygen.sh>"

WORKDIR /app
COPY . /app

RUN apk add --no-cache \
  bash \
  postgresql-client \
  tzdata \
  libc6-compat

ENV KEYGEN_EDITION="CE" \
    KEYGEN_MODE="singleplayer" \
    RAILS_LOG_TO_STDOUT="1" \
    PORT="3000" \
    BIND="0.0.0.0"

RUN chmod +x /app/scripts/entrypoint.sh && \
  adduser -h /app -g keygen -u 1000 -s /bin/bash -D keygen && \
  chown -R keygen:keygen /app

COPY --from=build --chown=keygen:keygen \
  /usr/local/bundle/ /usr/local/bundle

USER keygen

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
CMD ["web"]
