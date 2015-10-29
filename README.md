# lita

Currently runs on a machine in @marten's home. Tell him when you need updates deployed.

## Development

Requires Ruby & Redis, http://docs.lita.io/getting-started/installation/#manual-installation

`bundle install` to setup the relevant gem dependencies.

`lita start` runs lita based on the current config.

Once done you can run the `lita start` command as above and get a lita shell.
Then go ahead and use lita commands from the shell for testing, e.g. `lita project galaxy` to run the `lita-zooniverse-projects` plugin.

## Production
Set the LITA_ENV variable to run in production mode on start `LITA_ENV=production lita start`.

Note: If running in production mode then slack gem needs an token env var token
and won't start without a valid one (see lita_config.rb).
