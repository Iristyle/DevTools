[CmdletBinding(DefaultParametersetName='SinglePkg')]
param(
  [Parameter()]
  [string]
  $PrivateApiKey = $Env:DEVTOOLS_NUGET_PRIVATE_KEY,

  [Parameter()]
  [string]
  $PublicApiKey = $Env:DEVTOOLS_NUGET_PUBLIC_KEY,

  [Parameter(Mandatory = $false)]
  [string]
  $Source = $Env:DEVTOOLS_NUGET_PRIVATE_SOURCE,

  [Parameter(ParameterSetName = 'SinglePkg', Mandatory = $true, Position = 0)]
  [string]
  [ValidateScript({ (Get-ChildItem "$_.NuSpec" -Recurse).Count -gt 0})]
  $PackageName,

  [Parameter(ParameterSetName = 'AllPkgs')]
  [Switch]
  $All = $false,

  [Parameter(Mandatory = $false)]
  [switch]
  $Push,

  [Switch]
  $KeepPackages
)

function Get-CurrentDirectory
{
  $thisName = $MyInvocation.MyCommand.Name
  [IO.Path]::GetDirectoryName((Get-Content function:$thisName).File)
}

function Get-NugetPath
{
  Write-Host 'Executing Get-NugetPath'
  Get-ChildItem -Path (Get-CurrentDirectory) -Include 'nuget.exe' -Recurse |
    Select -ExpandProperty FullName -First 1
}

function Get-PackagesList([string] $source)
{
  Write-Host "Retrieving package list from $source..."
  # TODO: handle -Prerelease
  $list = .\nuget list -Source $source -NonInteractive
  $packages = @{}
  $list |
    ? { $_ -notmatch '^Using credentials' } |
    % {
      $packageDef = $_ -split '\s'
      $packages."$($packageDef[0])" = $packageDef[1];
    }

  Write-Host "Found $($packages.Count) packages"
  return $packages
}

function Test-IsVersionNewer([string]$base, [string]$new)
{
  # no base version - let this go through
  if (!$base) { return $true }

  if ([string]::IsNullOrEmpty($new))
  {
    Write-Error "New version cannot be empty"
    return $false
  }

  # TODO: naive impl of SemVer handling since its the exception
  # always let new SemVers go through
  if ($new -match '\-.*$') { return $true }

  return [Version]$new -gt [Version]$base
}

function Restore-Nuget
{
  Write-Host 'Executing Restore-Nuget'
  $nuget = Get-NugetPath

  if ($nuget -ne $null)
  {
      &"$nuget" update -Self | Write-Host
      return $nuget
  }

  $nugetPath = Join-Path (Get-CurrentDirectory) 'nuget.exe'
  (New-Object Net.WebClient).DownloadFile('http://nuget.org/NuGet.exe', $nugetPath)

  return Get-NugetPath
}

function Invoke-Pack([Hashtable]$packages, $include = '*.nuspec')
{
  $currentDirectory = Get-CurrentDirectory
  Write-Host "Invoke-Pack running against $currentDirectory for $include"

  Get-ChildItem -Path $currentDirectory -Include $include -Recurse |
    ? { (Split-Path $_.DirectoryName -Leaf) -ne 'packages' } |
    % {
      Write-Verbose "Found package file $_"
      $csproj = Join-Path $_.DirectoryName ($_.BaseName + '.csproj')
      if (Test-Path $csproj)
      {
        # TODO: yank this csproj stuff or make it parse like nuspec
        &$script:nuget pack "$csproj" -Prop Configuration=Release -Exclude '**\*.CodeAnalysisLog.xml'
      }
      else
      {
        $spec = [Xml](Get-Content $_)
        $id = $spec.package.metadata.id
        $version = $spec.package.metadata.version
        $base = $packages.$id
        Write-Verbose "Local package $id - version $version / remote $base"
        if (Test-IsVersionNewer $base $version)
        {
          &$script:nuget pack $_
        }
        else
        {
          Write-Host "[SKIP] : Package $id matches server $version"
        }
      }
    }
}

function Invoke-Push
{
  $currentDirectory = Get-CurrentDirectory
  Write-Host "Invoke-Push running against $currentDirectory"

  Get-ChildItem *.nupkg |
    % {
     Write-Host "Pushing $_ to source $source"
     if ($source -eq '') { &$script:nuget push $_ $PrivateApiKey }
     else { &$script:nuget push $_ $PrivateApiKey -source $source }
    }
}

$script:nuget = Restore-Nuget
del *.nupkg

$packages = Get-PackagesList $Source

if ($PsBoundParameters.PackageName)
  { Invoke-Pack $packages "$PackageName.nuspec" }
else
  { Invoke-Pack $packages }

if ($Push) { Invoke-Push }
if (!$KeepPackages) { del *.nupkg }
