$psModulePath = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)) "WindowsPowerShell\Modules";
$poshCdeModuleFolderPath = Join-Path $psModulePath "posh-cde";

if(-not (Test-Path $poshCdeModuleFolderPath -PathType Container))
{
    mkdir $poshCdeModuleFolderPath | Out-Null;
}
$moduleFileName = "posh-cde.psm1";
$poshCdeModuleFilePath = Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) $moduleFileName;
$poshCdeModuleFileDstPath = Join-Path $poshCdeModuleFolderPath $moduleFileName;
copy $poshCdeModuleFilePath $poshCdeModuleFileDstPath;
Import-Module $poshCdeModuleFileDstPath;