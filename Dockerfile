FROM ruby:2.7
WORKDIR /app
ARG LITA_ENV=production
ENV PORT=80

RUN apt-get update && \
    apt-get install --no-install-recommends -y git libssl-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ADD ./Gemfile /app/
ADD ./Gemfile.lock /app/

RUN if [ "$LITA_ENV" = "development" ]; then bundle install; else bundle install --without development test; fi

ADD ./ /app

EXPOSE 80

CMD ["bash", "/app/docker/start.sh"]
