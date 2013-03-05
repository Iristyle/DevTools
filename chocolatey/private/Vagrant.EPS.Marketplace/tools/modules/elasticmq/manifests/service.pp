define elasticmq::service(
  $bind_host = '0.0.0.0',
  $bind_port = '9324',
  $host = 'localhost',
  $port = '9324',
  $ensure = 'running',
  $storage_type = 'in-memory',
  $sqs_enabled = 'true'
) {

  file { 'elasticmq_config':
    ensure    => file,
    path      => "/opt/elasticmq/conf/elasticmq.conf",
    content   => template("${module_name}/elasticmq.conf.erb"),
    require   => Class['elasticmq'],
  }

  file { 'elasticmq_logback':
    ensure    => file,
    path      => "/opt/elasticmq/conf/logback.xml",
    content   => template("${module_name}/logback.xml.erb"),
    require   => Class['elasticmq'],
  }

  file { 'elasticmq_logfile':
    ensure    => file,
    path      => "/var/log/elasticmq-${port}.log",
    require   => Class['elasticmq'],
    group     => 'elasticmq',
    owner     => 'elasticmq',
  }

  file { 'elasticmq_upstart':
    ensure    => file,
    path      => "/etc/init/elasticmq-server.conf",
    content   => template("${module_name}/elasticmq.upstart.erb"),
    require   => File['elasticmq_config'],
  }

  file { "/etc/init.d/elasticmq-server":
    ensure    => link,
    target    => "/lib/init/upstart-job",
    require   => File['elasticmq_upstart'],
    notify    => Service["elasticmq-server"],
  }

  service { "elasticmq-server":
    ensure    => $ensure,
    provider  => 'upstart',
    require   => [ Class['elasticmq'],
                   File['elasticmq_upstart'],
                   File["/etc/init.d/elasticmq-server"],
                   File['elasticmq_logfile'] ],
  }
}
