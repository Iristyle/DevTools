#
# To run interactively on the VM, use this command:
#   sudo puppet apply --verbose --modulepath=/tmp/vagrant-puppet/modules-0/ /tmp/vagrant-puppet/manifests/redis-elasticsearch-riak.pp
# (That folder is synced locally to the folder on the host machine.)
#

# https://github.com/basho/puppet-riak/wiki/Class%5Briak%5D%3A-Parameters-and-Configuration
class { 'riak':
  version => '1.3.0',
  cfg => {
    riak_kv => {
      storage_backend => '__atom_riak_kv_eleveldb_backend',
      map_js_vm_count => 24,
      reduce_js_vm_count => 24
    },
    riak_control => {
      enabled => true,
      auth => '__atom_none',
      admin => true
    }
  }
}

class elasticsearch {
  $es_deb = 'elasticsearch-0.20.5.deb'
  $es_dl = "https://download.elasticsearch.org/elasticsearch/elasticsearch/$es_deb"

  if defined(Package['curl']) == false {
    package { 'curl':
      ensure => "installed"
    }
  }

  package { 'openjdk-7-jre-headless':
    ensure => 'installed',
  }

  exec { 'download_elasticsearch':
    command       => "/usr/bin/curl -o $es_deb $es_dl",
    cwd           => '/tmp',
    creates       => "/tmp/${es_deb}",
    require       => Package['curl'],
  }

  package { 'install_elasticsearch':
    provider => dpkg,
    ensure   => latest,
    source   => "/tmp/${es_deb}",
    require  => [Exec['download_elasticsearch'], Package['openjdk-7-jre-headless']],
  }
}

class elasticsearch-head {
  exec { 'elasticsearch-head':
    command => 'sudo /usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head',
    path    => ['/usr/bin', '/bin'],
    require => Class['elasticsearch'],
  }
}

class elasticsearch-bigdesk {
  exec { 'elasticsearch-bigdesk':
    command => 'sudo /usr/share/elasticsearch/bin/plugin -install lukas-vlcek/bigdesk/2.0.0',
    path    => ['/usr/bin', '/bin'],
    require => Class['elasticsearch'],
  }
}

# https://github.com/logicalparadox/puppet-redis
class { 'redis':
  redis_ver => '2.6.10',
}

redis::service { 'redis_6379':
  config_bind => '0.0.0.0',
  port   => '6379',
}

class { 'elasticmq':
  elasticmq_ver => '0.6.3'
}

elasticmq::service { 'elasticmq_9324':
  # HACK: NGinx listens on 9324 until new version of elasticmq
  # and proxies to elasticmq 9323
  # https://github.com/adamw/elasticmq/pull/4
  bind_port   => '9323',
  port        => '9324'
}

class rediscommander {
  $commander_path = '/opt/rediscommander'

  # TODO: use the nodejs / npm provider
  # https://github.com/puppetlabs/puppetlabs-nodejs
  exec { 'npm-install-redis-commander':
    command => 'sudo npm install -g redis-commander@0.0.6',
    path    => ['/usr/bin', '/bin'],
  }

  file { $commander_path : ensure => "directory" }

  file { "$commander_path/Procfile" :
    source => '/tmp/vagrant-puppet/manifests/rediscommander/Procfile',
    require => Exec['npm-install-redis-commander'],
  }

  exec { 'foreman-export-rediscommander' :
    cwd     => $commander_path,
    command => 'nf export -t upstart -o /etc/init -a rediscommander -p 8081 -u vagrant -l /var/log/upstart/rediscommander.log',
    notify  => Service["rediscommander"],
    path    => ['/usr/bin', '/bin'],
    require => File["$commander_path/Procfile"],
  }

  service { 'rediscommander' :
    ensure => 'running',
    enable => true,
  }
}

class fakes3 {
  $fakes3_path = '/opt/fakes3'
  $fakes3_port = 4568

  package { 'fakes3':
    ensure   => '0.1.5',
    provider => 'gem',
  }

  file { $fakes3_path : ensure => "directory" }

  file { "$fakes3_path/Procfile" :
    source => '/tmp/vagrant-puppet/manifests/fakes3/Procfile',
    require => Package['fakes3'],
  }

  exec { 'foreman-export-fakes3' :
    cwd     => $fakes3_path,
    command => "nf export -t upstart -o /etc/init -a fakes3 -p $fakes3_port -u vagrant -l /var/log/upstart/fakes3.log",
    notify  => Service["fakes3"],
    path    => ['/usr/bin', '/bin'],
    require => File["$fakes3_path/Procfile"],
  }

  service { 'fakes3' :
    ensure => 'running',
    enable => true,
  }
}

class marketusers {
  group { 'deployers' : ensure => present }
  group { 'market-web' : ensure => present }
  group { 'market-api' : ensure => present }

  user { 'vagrant' :
    groups => ['deployers'],
    require => Group['deployers'],
  }

  user { 'market-web' :
    ensure => present,
    home => '/home/market-web',
    gid => 'market-web',
    groups => ['deployers'],
    require => [ Group['deployers'], Group['market-web'] ],
  }

  user { 'market-api' :
    ensure => present,
    home => '/home/market-api',
    gid => 'market-api',
    groups => ['deployers'],
    require => [ Group['deployers'], Group['market-api'] ],
  }
}

class marketpaths {
  $web = "/opt/marketplace-web"
  $api = "/opt/marketplace-api"
  file {[ "$web", "$web/shared", "$web/shared/log",
          "$api", "$api/shared", "$api/shared/log"]:
  # http://askubuntu.com/questions/46331/how-to-avoid-using-sudo-when-working-in-var-www/46371
  # user = rwx 7 / group = rx 5 / world = nothing
  # leading 2 is set group user id -- inherit bit on new files / dirs
    mode => 2750,
    owner => vagrant,
    group => deployers,
    ensure => directory,
    recurse => true,
    require => Class['marketusers'],
  }
}

class dashboard {
  file { '/opt/dashboard' :
    source => '/tmp/vagrant-puppet/manifests/dashboard',
    mode => 2755,
    recurse => true
  }

  file { '/opt/dashboard/log' :
    ensure => "directory"
  }
}

class nginx-config {
  file { '/etc/nginx/conf.d/default.conf' :
    notify  => Service["nginx"],
    ensure => absent
  }

  # NOTE: this path is different from production box with sites-enabled
  file { '/etc/nginx/conf.d/market.conf' :
    # ensures Nginx is restarted
    notify  => Service["nginx"],
    source => '/tmp/vagrant-puppet/manifests/market',
    require => [ Class['marketpaths'], File['/etc/nginx/conf.d/default.conf']]
  }

  # define the service to restart
  service { "nginx":
    ensure  => "running",
    enable  => "true",
  }
}

# declare the classes so they run
class {'elasticsearch':}
class {'elasticsearch-head':}
class {'elasticsearch-bigdesk':}
class {'rediscommander':}
class {'fakes3':}
class {'marketusers':}
class {'marketpaths':}
class {'dashboard':}
class {'nginx-config':}
