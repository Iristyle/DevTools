# Private Chocolatey Packages

These packages are those which we are kept in the private MyGet feed, but not
because they contain secrets, but rather they are not appropriate for external
consumption.

Remember that this is still a public GitHub repository, and as such no private
information such as passwords or keys should __EVER__ be stored here.

### Vagrant.EPS.Marketplace

Builds on our Vagrant VM with Ubuntu 12.04 that has been generated with
Veewee.  See the `AdminScripts` repo for the relevant Veewee scripts.

The base box on S3 includes:

* Ubuntu 12.04-2-server-amd64
* NGinx 1.2.7
* Mono 3.0.1 w/ XSP4 2.10-1 and fastcgi 2.10-1
* Node 0.8.21 / NPM 1.2.11
* Ruby 1.9.3-p385 / RubyGems 1.8.25
* Puppet 3.1.0

The additional Vagrant customizations add:

* Riak 1.3.0-1 with Control enabled
* ElasticSearch 0.20.5 / ElasticSearch Head
* Redis 2.6.10
* Redis Commander 0.0.6
