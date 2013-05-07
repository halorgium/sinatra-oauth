# sinatra-oauth

To get started:

    $ gem install bundler

Then install dependencies

    $ bundle

There are 2 sinatra apps:

## OAuth server:
Start this on port 4567

    $ ruby server.rb

## OAuth client:
Start this on port 4568(done automatically)

    $ ruby client.rb

To bootstrap it all, go to `http://localhost:4568/bootstrap`, this will automigrate the database.
Now if you visit `http://localhost:4568/`, you should be able to try it out.

If you need to clear your session, visit `http://localhost:4568/reset`.

This is setting up the tokens between the two applications.
You will be able to try out a few cases, like reseting the database and trying to use the invalid token.
