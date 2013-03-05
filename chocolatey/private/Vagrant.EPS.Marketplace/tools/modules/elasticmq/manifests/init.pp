# based *heavily* on the redis module
class elasticmq($elasticmq_ver = '0.6.3') {

  $elasticmq_tar = "elasticmq-$elasticmq_ver.tar.gz"
  $elasticmq_dl = "https://s3-eu-west-1.amazonaws.com/softwaremill-public/$elasticmq_tar"

  if defined(Package['curl']) == false {
    package { "curl":
      ensure => "installed"
    }
  }

  group { "elasticmq":
    ensure => present
  }

  user { "elasticmq":
    ensure        => present,
    gid           => 'elasticmq',
    managehome    => true,
    home          => '/opt/elasticmq',
    shell         => '/bin/false',
    comment       => 'elasticmq-server',
    require       => Group['elasticmq'],
  }

  exec { 'download_elasticmq':
    command       => "curl -o $elasticmq_tar $elasticmq_dl",
    cwd           => '/tmp',
    creates       => "/tmp/${elasticmq_tar}",
    require       => Package['curl'],
    path          => ['/usr/bin/', '/bin/'],
  }

  exec { 'extract_elasticmq':
    command       => "tar xfv ${elasticmq_tar}",
    cwd           => "/tmp",
    creates       => "/tmp/elasticmq-${elasticmq_ver}",
    require       => [ Exec['download_elasticmq'] ],
    timeout       => 0,
    path          => [ '/usr/bin/', '/bin/', '/opt/elasticmq/bin' ],
  }

  file { '/opt/elasticmq/':
    source        => "/tmp/elasticmq-${elasticmq_ver}",
    ensure        => directory,
    group         => 'elasticmq',
    owner         => 'elasticmq',
    replace       => true,
    recurse       => true,
    require       => [ User['elasticmq'],
                       Exec['extract_elasticmq'] ],
  }
}
