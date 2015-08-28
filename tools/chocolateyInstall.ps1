﻿$psModulePath = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)) "WindowsPowerShell\Modules";
$poshCdeModuleFolderPath = Join-Path $psModulePath "posh-cde";

if(-not (Test-Path $poshCdeModuleFolderPath -PathType Container))
{
    mkdir $poshCdeModuleFolderPath | Out-Null;
}

$moduleFileName = "posh-cde.psm1";
$poshCdeModuleFilePath = Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) $moduleFileName;
$poshCdeModuleFileDstPath = Join-Path $poshCdeModuleFolderPath $moduleFileName;
copy $poshCdeModuleFilePath $poshCdeModuleFileDstPath;

if(-not (Test-Path $profile))
{
    New-Item $profile -ItemType File;
}

("Import-Module {0}" -f $poshCdeModuleFileDstPath) | Out-File $profile -Append;
& $profile;