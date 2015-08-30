$script:EnabledPoshCde = $true;
$env:PoshCdeTempDir = Join-Path $env:Temp "PoshCde";
$env:PoshCdeGlobalHistoryFile = "history.txt";
$env:PoshCdeGlobalHistoryLength = 100;
$script:PoshCdeLocalHistory = New-Object System.Collections.Generic.LinkedList[string];
$script:PoshCdeLocalHistoryLength = 100;

function Read-PoshCdeTempFile
{
    $tempFilePath = (Join-Path $env:PoshCdeTempDir $env:PoshCdeGlobalHistoryFile);

    if(Test-Path $tempFilePath)
    {
        gc $tempFilePath -Encoding UTF8;
    }
}

function Write-PoshCdeTempFile
{
    param
    (
        [string[]] $Paths,
        [switch] $Append
    )
    process 
    {
        if(-not (Test-Path $env:PoshCdeTempDir))
        {
            Write-Verbose "Didn't find temp folder. creating $env:PoshCdeTempDir";
            mkdir $env:PoshCdeTempDir | Out-Null;
        }

        $tempFilePath = (Join-Path $env:PoshCdeTempDir $env:PoshCdeGlobalHistoryFile);

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

function Remove-PoshCdeHistory
{
    $tempFilePath = (Join-Path $env:PoshCdeTempDir $env:PoshCdeGlobalHistoryFile);
    if(Test-Path $tempFilePath)
    {
        rm $tempFilePath -Verbose;
    }
    else
    {
        Write-Warning "Didn't find the history file";
    }
}

function Disable-PoshCde
{
    process
    {
        $script:EnabledPoshCde = $false;
    }
}

function Enable-PoshCde
{
    process
    {
        $script:EnabledPoshCde = $true;
    }
}

function Add-PoshCdeHistory
{
    param
    (
        [string] $path
    )
    process
    {
        $script:PoshCdeLocalHistory.AddFirst($path) | Out-Null;
        if($script:PoshCdeLocalHistory.Count -gt $script:PoshCdeLocalHistoryLength)
        {
            $script:PoshCdeLocalHistory.RemoveLast() | Out-Null;
        }

        Write-PoshCdeTempFile $path;
        Write-PoshCdeTempFile ($history | sort -Unique | Select-Object -First ($env:PoshCdeGlobalHistoryLength-1)) -append;   
    }
}

function Set-PoshCdeLocationMinus
{
    process
    {
        if($script:EnabledPoshCde)
        {
            if($script:PoshCdeLocalHistory.Count -ne 0)
            {
                $res = $script:PoshCdeLocalHistory | peco;
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

            Add-PoshCdeHistory $(pwd);
        }
    }
}

function Set-PoshCdELocation
{
    [CmdletBinding()]
    param
    (
        [string] $arg
    )
    process
    {
        if($script:EnabledPoshCde)
        {
            if([System.IO.Path]::IsPathRooted($arg))
            {
                $targetPath = $arg;
            }
            else
            {
                $targetPath = Join-Path $(pwd) $arg;
            }

            $history = Read-PoshCdeTempFile;
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
            
            Add-PoshCdEHistory $(pwd);
        }
        else
        {
            Set-Location $arg;
        }
    }
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

Set-Item alias:cd -Value 'Set-PoshCdELocation';
Set-Item alias:cd- -Value 'Set-PoshCdeLocationMinus';
