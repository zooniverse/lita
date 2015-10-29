# lita

Currently runs on a machine in @marten's home. Tell him when you need updates deployed.

## Development

Requires Ruby & Redis, http://docs.lita.io/getting-started/installation/#manual-installation

`bundle install` to setup the relevant gem dependencies.

`lita start` runs lita based on the current config.

To get a local console for testing development:

1. Comment out the `gem "lita-slack"` line in Gemfile and re-run `bundle install`
 + Then slack gem needs an token env var token so won't start without a valid one (see lita_config.rb).
2. Change `lita_config.rb` line `config.robot.adapter = :slack` to `config.robot.adapter = :shell` http://docs.lita.io/getting-started/usage/#shell-adapter

Once done you can run the `lita start` command as above and get a lita shell.
Then go ahead and use lita commands from the shell for testing, e.g. `lita project galaxy` to run the `lita-zooniverse-projects` plugin.
