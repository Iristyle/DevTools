# must match whats in the Vagrantfile
$packageName = 'Vagrant.EPS.Marketplace'
$boxName = 'ubuntu-12.04.2-server-amd64-market'
$vagrantPath = "$Env:SystemDrive\vagrant\bin"
$rubyPath = "$Env:SystemDrive\ruby193\bin"
$virtualBoxPath = "$Env:ProgramFiles\Oracle\VirtualBox"
$elasticSearchVersion = '0.20.5'
$redisVersion = '2.6.10'
$riakVersion = '1.3.0'
$installPath = Join-Path $ENV:LOCALAPPDATA 'Vagrant\EPS.Marketplace'

function Get-CurrentDirectory
{
  $thisName = $MyInvocation.MyCommand.Name
  [IO.Path]::GetDirectoryName((Get-Content function:$thisName).File)
}

function Which([string]$cmd)
{
  Get-Command -ErrorAction SilentlyContinue $cmd |
    Select -ExpandProperty Definition
}

function Test-Administrator
{
  $user = [Security.Principal.WindowsIdentity]::GetCurrent()
  $adminRole = [Security.Principal.WindowsBuiltinRole]::Administrator
  (New-Object Security.Principal.WindowsPrincipal $user).IsInRole($adminRole)
}

function Test-CommandConfigured
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $Name
  )

  $path = Which $Name
  if ($path) { Write-Host "$Name found at $path" }

  return ($path -eq $null)
}

function Add-ToPath
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $Path
  )

  $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
  [Environment]::SetEnvironmentVariable('PATH', "$userPath;$Path", 'User')
  $Env:PATH += ";$Path"
}

function Add-FirewallExclusions
{
  Write-Host "Registering Marketplace VM firewall exclusions"
  netsh advfirewall firewall add rule name="EPS-Market-VM-Riak-Http" dir=in protocol=tcp localport=8098 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-Riak-ProtoBuf" dir=in protocol=tcp localport=8087 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-Redis" dir=in protocol=tcp localport=6379 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-Redis-Commander" dir=in protocol=tcp localport=8081 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-ElasticSearch" dir=in protocol=tcp localport=9200 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-ElasticSearch" dir=in protocol=tcp localport=9300 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-NGinx" dir=in protocol=tcp localport=9090 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-FakeS3" dir=in protocol=tcp localport=4568 action=allow
  netsh advfirewall firewall add rule name="EPS-Market-VM-ElasticMQ" dir=in protocol=tcp localport=9324 action=allow
}

function Test-RestPath
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $Url,

    [Parameter(Mandatory = $false)]
    [ScriptBlock]
    $Test,

    [Parameter(Mandatory = $false)]
    [string]
    $FailMessage
  )

  try
  {
    $response = Invoke-RestMethod $Url
    if ($Test)
    {
      if (!(&$Test $response ))
      {
        throw "$FailMessage`nResponse invalid: `n`n$response`n"
      }
    }

    Write-Host "Successfully connected to $Url"
  }
  catch [System.Exception]
  {
    Write-Warning "Failed to connect to $url `n$($_.Exception.Message)"
  }
}

function Test-VirtualMachineConnections
{
  ### NGinx Stats Page
  @{ Url = 'http://localhost:9090/nginx_status'},

  ### Redis
  @{
    Url = 'http://localhost:8081/apiv1/server/info';
    Test = {
      $version = $args[0] |
        Select -ExpandProperty info |
        ? { $_.Key -eq 'Redis version' } |
        Select -ExpandProperty Value -First 1
      $version -eq $redisVersion
    };
    FailMessage = "Redis Commander must respond and Redis must be version $redisVersion";
  },
  @{
    Url = 'http://localhost:8081/apiv1/connection';
    Test = { $args[0] -eq 'True' };
  },

  ### ElasticSearch
  @{
    Url = 'http://localhost:9200';
    Test = {
      $version = $args[0] |
        Select -ExpandProperty Version |
        Select -ExpandProperty number
      $version -eq $elasticSearchVersion
    };
    FailMessage = "ElasticSearch must respond and be version $elasticSearchVersion";
  },
  @{
    Url = 'http://localhost:9200/_plugin/head/'
    FailMessage = 'ElasticSearch head not installed'
  },
  @{
    Url = 'http://localhost:9200/_plugin/bigdesk/'
    FailMessage = 'ElasticSearch BigDesk not installed'
  },

  ### Riak
  @{
    Url = 'http://localhost:8098/stats';
    Test = {
      ($args[0].riak_core_version -eq $riakVersion -and `
        $args[0].riak_control_version -eq $riakVersion)
    };
    FailMessage = "Riak Core and Control must respond and be version $riakVersion"
  },
  @{Url = 'http://localhost:8098/admin'},

  ### Fake S3
  @{
    Url = 'http://localhost:4568';
    FailMessage = 'Fake S3 not responding on port 4568';
  },

  ### ElasticMQ
  @{
    Url = 'http://localhost:9324/?Action=ListQueues';
    FailMessage = 'ElasticMQ not responding on port 9324';
  } |
    % { Test-RestPath @_ }
}

try {
  # HACK: must be run as admin (Start-ChocolateyProcessAsAdmin won't work well)
  if (Test-Administrator) { Add-FirewallExclusions } `
  else { Write-Warning 'Manually add firewall exclusions for ports 8098, 8087, 6379, 8081, 9200, 9300 and 9090' }

  if (!(Test-CommandConfigured 'Vagrant'))
  {
    Add-ToPath $vagrantPath
    Add-ToPath $rubyPath

    if (!(Which vagrant))
    {
      Write-Error @"
Vagrant cannot be found.

* Ensure the Vagrant package is installed with cinst Vagrant -force
* Reinstall this package with cinst $packageName -force
"@
    }
  }

  if (!(Test-CommandConfigured 'VBoxManage'))
  {
    Add-ToPath $virtualBoxPath
    if (!(Which VBoxManage))
    {
      Write-Error @"
VBoxManage cannot be found.

* Ensure VirtualBox package is installed with cinst VirtualBox -force
* Reinstall this package with cinst $packageName -force
"@
    }
  }

  if (!(Test-Path $installPath)) { New-Item $installPath -Type Directory}
  Push-Location $installPath
  Copy-Item "$(Get-CurrentDirectory)\*" -Recurse -Force

  $boxRegistered = vagrant box list |
    ? { $_ -eq $boxName } |
    Measure-Object |
    Select -ExpandProperty Count
  $dotVagrantExists = Test-Path '.vagrant'

  if ($dotVagrantExists -and (!$boxRegistered))
  {
    Write-Warning ".vagrant file found, but box not registered in Vagrant!"
  }

  if ($dotVagrantExists) { vagrant reload } `
  else { vagrant up  }

  Write-ChocolateySuccess $packageName

$installDetails = @"
Congratulations!

The magic of Willy Wonka and his band of merry goats has generated a local VM with:

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

The Vagrant files are stored at:
$installPath

The virtual machine may also be accessed by connecting with SSH:

 address: localhost:2222
    user: vagrant
key file: $installPath\vagrant

Should anything go horribly wrong, there are Vagrant commands which can be used
to remove or reinstall a VM.  More information available at:

http://stackoverflow.com/q/11424690/87793
"@

  Write-Host $installDetails

  Test-VirtualMachineConnections
} catch {
  Write-ChocolateyFailure $packageName $($_.Exception.Message)
  throw
}
