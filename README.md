Setup
=========

Run `bundle install`

aws-utils
=========

Example command to run locally (instead of installing the gem):

    ruby -I lib bin/cw-logs-reader.rb --aws-profile <profile from ~/.aws/config> --log-groups 'my-app-prod'  --log-streams '.*' --begin-at '2014-07-24T18:12:40Z' --end-at 'now'
