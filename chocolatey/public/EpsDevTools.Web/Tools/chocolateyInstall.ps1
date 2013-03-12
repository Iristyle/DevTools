try {

  # Some packages wont work as a dependency. When you try to use them,
  # you get the following error:
  # "External packages cannot depend on packages that target projects."
  # To work around this, we just install the packages as part of our
  # script.
  # See here for more info: http://nuget.codeplex.com/workitem/595
  cinst Console2

  # install required NPM packages
  npm install -g coffee-script
  npm install -g coffeelint
  npm install -g bower
  npm install -g grunt-cli
  npm install -g http-server
  npm install -g jshint

  # install required gems
  gem update --system
  gem install bundler
  gem install capistrano

  Write-ChocolateySuccess 'EpsDevTools'
} catch {
  Write-ChocolateyFailure 'EpsDevTools' $($_.Exception.Message)
  throw
}
