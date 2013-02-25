try {

  # Some packages wont work as a dependency. When you try to use them,
  # you get the following error:
  # "External packages cannot depend on packages that target projects."
  # To work around this, we just install the packages as part of our
  # script.
  # See here for more info: http://nuget.codeplex.com/workitem/595
  cinst Console2

  # install required gems
  gem update --system
  gem install bundler
  gem install capistrano

  # Set up git diff/merge tool
  git config --global mergetool.diffmerge.cmd '\"C:\Program Files\SourceGear\Common\DiffMerge\sgdm.exe\" --merge --result=\"$MERGED\" \"$LOCAL\" \"$BASE\" \"$REMOTE\" --title1=\"Mine\" --title2=\"Merging to: $MERGED\" --title3=\"Theirs\"'
  git config --global mergetool.diffmerge.trustExitCode true
  git config --global difftool.diffmerge.cmd '\"C:\Program Files\SourceGear\Common\DiffMerge\sgdm.exe\"  \"$LOCAL\" \"$REMOTE\" --title1=\"Previous Version ($LOCAL)\" --title2=\"Current Version ($REMOTE)\"'

  $defaultMerge = git config --get merge.tool
  if (!$defaultMerge)
  {
    git config --global merge.tool diffmerge
    git config --global mergetool.keepBackup false
  }

  $defaultDiff = git config --get diff.tool
  if (!$defaultDiff)
  {
    git config --global diff.tool diffmerge
  }

  $defaultPush = git config --get push.default
  if (!$defaultPush)
  {
    git config --global push.default simple
  }

  Write-ChocolateySuccess 'EpsDevTools'
} catch {
  Write-ChocolateyFailure 'EpsDevTools' $($_.Exception.Message)
  throw 
}
