function New-ItemRecursive
{
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $HiveName,

    [Parameter(Mandatory = $true)]
    [string]
    $Path
  )

  $running = "Registry::$HiveName"
  $Path -split '\\' |
    % {
      $proposed = "$running\$_"
      if (!(Test-Path $proposed))
      {
        New-Item -Path $running -Name $_ | Out-Null
      }
      $running = $proposed
    }
}

function Register-WindowsUserLoginScript
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    [Parameter(Mandatory = $true)]
    [string]
    $Path
  )

  $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  $keys = (Get-Item -Path $run).Property

  if ($keys -icontains $Name)
  {
    Set-ItemProperty -Path $run -Name $Name -Value "`"$Path`"" | Out-Null
  }
  else
  {
    New-ItemProperty -Path $run -Name $Name -Value "`"$Path`"" | Out-Null
  }
}

function Register-WindowsUserLogoffScript
{
  # http://superuser.com/questions/345298/running-a-batch-file-on-logoff
  # http://technet.microsoft.com/en-us/library/ff404236.aspx
  # other info: http://serverfault.com/questions/377387/how-to-add-a-shutdown-script-not-by-using-gpedit-msc-or-active-directory
  # http://www.petri.co.il/forums/showthread.php?t=26892
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    [Parameter(Mandatory = $true)]
    [string]
    $Path
  )

  $params = @{
    HiveName = 'HKEY_CURRENT_USER';
    Path = 'Software\Policies\Microsoft\Windows\System\Scripts\Logoff';
  }
  New-ItemRecursive @params


  $logoff = "Registry::$($params.HiveName)\$($params.Path)"

  # prevent a double registration based on what's executing
  $scripts = Get-ChildItem $logoff |
    Get-ChildItem |
    Get-ItemProperty -Name Script -ErrorAction SilentlyContinue |
    Select -ExpandProperty Script
  if ($scripts.Count -gt 0) { return }

  $key = Get-ChildItem $logoff |
    Select -ExpandProperty Name -Last 1
  if ([string]::IsNullOrEmpty($key))
  {
    $key = 0
  }
  else
  {
    $key = [Int]($key -split '\\' | Select -Last 1) + 1
  }

  New-Item -Path $logoff -Name $key | Out-Null

  $keyValue = @{
    Path = "$logoff\$key";
    Name = 'DisplayName';
    PropertyType = 'String';
    Value = $Name;
  }
  New-ItemProperty @keyValue | Out-Null

  #$keyValue.Name = 'GPOName';
  #$keyValue.Value = '';
  #New-ItemProperty @keyValue

  New-Item -Path "$logoff\$key" -Name '0' | Out-Null

  $keyValue = @{
    Path = "$logoff\$key\0";
    Name = 'Script';
    PropertyType = 'String';
    Value = $Path;
  }
  New-ItemProperty @keyValue | Out-Null

  $keyValue.Name = 'Parameters';
  $keyValue.Value = '';
  New-ItemProperty @keyValue | Out-Null

  $keyValue.PropertyType = 'Binary';
  $keyValue.Name = 'ExecTime';
  $keyValue.Value = ([byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00));
  New-ItemProperty @keyValue | Out-Null
}
