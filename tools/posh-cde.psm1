$script:EnabledCdEnhance = $true;
$env:CdEnhanceTempDir = Join-Path $env:Temp "CdEnhance";
$env:CdEnhanceGlobalHistoryFile = "history.txt";
$env:CdEnhanceGlobalHistoryLength = 100;
$script:CdEnhanceLocalHistory = New-Object System.Collections.Generic.LinkedList[string];
$script:CdEnhanceLocalHistoryLength = 100;

function Read-CdeTempFile
{
    $tempFilePath = (Join-Path $env:CdEnhanceTempDir $env:CdEnhanceGlobalHistoryFile);

    if(Test-Path $tempFilePath)
    {
        gc $tempFilePath -Encoding UTF8;
    }
}

function Write-CdeTempFile
{
    param
    (
        [string[]] $Paths,
        [switch] $Append
    )
    process 
    {
        if(-not (Test-Path $env:CdEnhanceTempDir))
        {
            Write-Warning "Didn't find temp folder. creating $env:CdEnhanceTempDir";
            mkdir $env:CdEnhanceTempDir | Out-Null;
        }

        $tempFilePath = (Join-Path $env:CdEnhanceTempDir $env:CdEnhanceGlobalHistoryFile);

        if($Append)
        {
            $Paths | Out-File $tempFilePath -Encoding utf8 -Append;
        }
        else
        {
            $Paths | Out-File $tempFilePath -Encoding utf8 ;
        }


    }
}

function Remove-CdeHistory
{
    $tempFilePath = (Join-Path $env:CdEnhanceTempDir $env:CdEnhanceGlobalHistoryFile);
    if(Test-Path $tempFilePath)
    {
        rm $tempFilePath -Verbose;
    }
    else
    {
        Write-Warning "Didn't find the history file";
    }
}

function Disable-CdEnhance
{
    process
    {
        $script:EnabledCdEnhance = $false;
    }
}

function Enable-CdEnhance
{
    process
    {
        $script:EnabledCdEnhance = $true;
    }
}

function Add-CdeHistory
{
    param
    (
        [string] $path
    )
    process
    {
        $script:CdEnhanceLocalHistory.AddFirst($path) | Out-Null;
        if($script:CdEnhanceLocalHistory.Count -gt $script:CdEnhanceLocalHistoryLength)
        {
            $script:CdEnhanceLocalHistory.RemoveLast() | Out-Null;
        }

        Write-CdeTempFile $path;
        Write-CdeTempFile ($history | sort -Unique | Select-Object -First ($env:CdEnhanceGlobalHistoryLength-1)) -append;   
    }
}

function Set-CdeLocationMinus
{
    process
    {
        if($script:EnabledCdEnhance)
        {
            if($script:CdEnhanceLocalHistory.Count -ne 0)
            {
                $res = $script:CdEnhanceLocalHistory | peco;
                if(-not [string]::IsNullOrEmpty($res))
                {
                    Set-Location $res;
                }
                else
                {
                    return;
                }
            }
            else
            {
                return;
            }

            Add-CdeHistory $(pwd);
        }
    }
}

function Set-CdELocation
{
    [CmdletBinding()]
    param
    (
        [string] $arg
    )
    process
    {
        if($script:EnabledCdEnhance)
        {
            if([System.IO.Path]::IsPathRooted($arg))
            {
                $targetPath = $arg;
            }
            else
            {
                $targetPath = Join-Path $(pwd) $arg;
            }

            $history = Read-CdeTempFile;
            if(Test-Path $targetPath -Type Container)
            {
                Set-Location $arg;
            }
            else
            {
                $history | %{Write-Verbose $_};
                $res = ($history | peco --query $arg);
                if(-not [string]::IsNullOrEmpty($res))
                {
                    Set-Location $res;
                }
                else
                {
                    return;
                }
            }
            
            Add-CdEHistory $(pwd);
        }
        else
        {
            Set-Location $arg;
        }
    }
}

if((Get-Command peco) -eq $null)
{
    Write-Warning "This module requires peco";
    Write-Warning "If you already installed Chocoratly, run `"Choco install peco`"";
    Write-Warning "To install Chocoratly, run `"iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))`"";
    throw "Failed to import CdEnhance";
}

$script:alias = Get-Alias -Name "cd" -ErrorAction SilentlyContinue;
if($script:alias -eq $null)
{
    $script:orig_cd = "Set-Location";
}
else
{
    $script:orig_cd = $script:alias.Definition;
}
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Warning "If you are running Win10, default alias cd will disappear. Run `"Set-Alias cd Set-Location`" to restore.";
    set-item alias:cd -value $script:orig_cd
}

Set-Item alias:cd -Value 'Set-CdELocation';
Set-Item alias:cd- -Value 'Set-CdeLocationMinus';
