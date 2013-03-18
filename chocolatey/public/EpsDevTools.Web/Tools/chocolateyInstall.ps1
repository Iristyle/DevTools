try {

  # Some packages wont work as a dependency. When you try to use them,
  # you get the following error:
  # "External packages cannot depend on packages that target projects."
  # To work around this, we just install the packages as part of our
  # script.
  # See here for more info: http://nuget.codeplex.com/workitem/595
  cinst Console2

  # install required NPM packages
  $packages = @(
    'coffee-script@1.4.0',
    'coffeelint@0.5.4',
    'bower@0.8.5',
    'grunt-cli@0.1.6',
    'http-server@0.5.3',
    'jshint@1.1.0',
    'codo@1.5.6',
    'recess@1.1.6',
    'csslint@0.9.10'
  )

  npm install -g $packages

  # install required gems
  gem update --system
  gem install bundler
  gem install capistrano
  gem install twig

  Write-ChocolateySuccess 'EpsDevTools'
} catch {
  Write-ChocolateyFailure 'EpsDevTools' $($_.Exception.Message)
  throw
}
