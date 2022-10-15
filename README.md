# lita
## Usage

Head over to the Wiki for docs and help.

## Development

#### Manual setup
Requires Ruby & Redis, http://docs.lita.io/getting-started/installation/#manual-installation

`bundle install` to setup the relevant gem dependencies.

#### Docker setup

1. `docker-compose build` to build the local image for development

2. `docker-compose run -T --rm lita bundle exec rspec`

Alternatively get a console to interactively run code / debug tests

1. `docker-compose run --service-ports --rm lita bash` to launch a bash shell in the container

2. `bundle exec rspec` to run tests from the container

3. `lita start` to get a lita shell, where you can use lita commands from the shell for testing, e.g. `lita project galaxy` to run the `lita-zooniverse-projects` plugin.

Note: some handlers will not work unless they have the relevant configuration directives supplied as ENV vars,
E.g. locating Lintott via Foursquare, add the relevant ENV vars to your local dev env to test these specific handlers.

## Production
Set the LITA_ENV variable to run in production mode on start `LITA_ENV=production lita start`.

Note: If running in production mode then slack gem needs an token env var token and won't start without a valid one (see lita_config.rb).

## Deployment

Deployed automatically via [GitHub Actions](./github/workflows/deploy_lita.yml)
