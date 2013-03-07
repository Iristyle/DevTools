## Marketplace

### Installed Services

Service             Version   Mapped Port    Url

NGinx                1.2.7    80   / 9090    http://localhost:9090
                                             http://localhost:9090/nginx_status
Riak (HTTP)          $riakVersion    8098 / 8098    http://localhost:8098
Riak (ProtoBuf)               8087 / 8087
RiakControl                                  http://localhost:8098/admin
ElasticSearch        $elasticSearchVersion   9200 / 9200    http://localhost:9200
ElasticSearch                 9300 / 9300
ElasticSearch Head                           http://localhost:9200/_plugin/head/
ElasticSearch BigDesk                        http://localhost:9200/_plugin/bigdesk/
Redis                $redisVersion   6379 / 6379
Redis Commander      0.0.6    8081 / 8081    http://localhost:8081
FakeS3               0.1.5    4568 / 4568    http://localhost:4568
ElasticMQ            0.6.3    9324 / 9324    http://localhost:9324
Mono                 3.0.1
Mono-xsp4            2.10-1
Mono-fastcgi-server4 2.10-1
Node                 0.8.21
NPM                  1.2.11
Ruby                 1.9.3-p385
RubyGems             1.8.25
Puppet               3.1.0


#### Local Installation Directory

```powershell
$ENV:LOCALAPPDATA\Vagrant\EPS.Marketplace
```

### Accessing with SSH

 address: `localhost:2222`
    user: `vagrant`
key file: `$ENV:LOCALAPPDATA\Vagrant\EPS.Marketplace\vagrant`
