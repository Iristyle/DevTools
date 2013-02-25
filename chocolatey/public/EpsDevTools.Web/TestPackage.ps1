function Get-CurrentDirectory
{
  $thisName = $MyInvocation.MyCommand.Name
  [IO.Path]::GetDirectoryName((Get-Content function:$thisName).File)
}

$nugetSource = Get-CurrentDirectory

cuninst EpsDevTools.Web
cpack .\EpsDevTools.Web.nuspec
cinst EpsDevTools.Web -source `"`"$nugetSource`;http://chocolatey.org/api/v2/`"`"
