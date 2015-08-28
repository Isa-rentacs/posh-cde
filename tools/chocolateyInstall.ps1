$psFile = Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) "DeployModule.ps1";
Install-ChocolateyPowershellCommand 'posh-cde' $psFile;