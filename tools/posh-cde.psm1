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
    $script:EnabledPoshCde = $false;
}

function Enable-PoshCde
{
    $script:EnabledPoshCde = $true;
}

function Set-PoshCdeLocationIfSelected
{
    param
    (
        $CandidateDirs,
        $queryForPeco = [string]::Empty
    )
    process
    {
        if($CandidateDirs -eq $null)
        {
            Write-Error "There are not candidate dirs.";
        }
        else
        {
            $res = $CandidateDirs | peco --query=$queryForPeco;
            if(-not ([string]::IsNullOrEmpty($res)))
            {
                Set-Location $res;
                return $true;
            }
            else
            {
                return $false;
            }
        }
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

#
function IsNetworkPath
{
    param
    (
        $path
    )
    process
    {
        # heuristics to check whether current dir is network dir or not
        if([string]::IsNullOrEmpty(([System.IO.Path]::GetPathRoot($path))))
        {
            $true;
        }
        else
        {
            $false;
        }
    }
}

function GetUpperDirectories
{
    param
    (
        $path
    )
    process
    {
        $fullpath = $null;
        $current = $path;
        $ret = New-Object System.Collections.Generic.List[string];

        if(IsNetworkPath($current))
        {
            # Invoke string.split(string[], StringSplitOpeions)
            $fullpath = ($current.ToString().Split([string]"::", [System.StringSplitOptions]::RemoveEmptyEntries))[1];
        }
        else
        {
            $fullpath = $current;
        }

        $tmp = $fullpath;
        while(-not ([string]::IsNullOrEmpty(($tmp = (Split-Path $tmp -Parent)))))
        {
            $ret.Add($tmp);
        }

        $ret;
    }
}

function Set-PoshCdeLocationUp
{
    if($script:EnabledPoshCde)
    {
        if(-not (Set-PoshCdeLocationIfSelected (GetUpperDirectories (Get-Location))))
        {
            return;
        }

        Add-PoshCdeHistory (Get-Location);
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
                if(-not (Set-PoshCdeLocationIfSelected $script:PoshCdeLocalHistory))
                {
                    return;
                }
            }
            else
            {
                return;
            }

            Add-PoshCdeHistory (Get-Location);
        }
    }
}

function Set-PoshCdeLocation
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
                $targetPath = Join-Path (Get-Location) $arg;
            }

            $history = Read-PoshCdeTempFile;
            if(Test-Path $targetPath -Type Container)
            {
                Set-Location $arg;
            }
            else
            {
                if(-not (Set-PoshCdeLocationIfSelected -CandidateDirs $history -queryForPeco $arg))
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

Set-Item alias:cd -Value 'Set-PoshCdeLocation';

# For Win8.1, alias with symbols seems not working.
Set-Alias cd- -Value 'Set-PoshCdeLocationMinus' -Option AllScope -Scope Global -Force;
Set-Alias cdp -Value 'Set-PoshCdeLocationMinus' -Option AllScope -Scope Global -Force;
Set-Alias up -Value "Set-PoshCdeLocationUp" -Option AllScope -Scope Global -Force;

# Called when this module is "Remove-Module"ed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Warning "If you are running Win10, default alias cd will disappear. Run `"Set-Alias cd Set-Location`" to restore.";
    Set-Item alias:cd -value $script:orig_cd
    Remove-Item alias:cd-;
    Remove-Item alias:cdp;
    Remove-Item alias:up;
}
