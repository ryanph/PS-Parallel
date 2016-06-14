<# 
.SYNOPSIS 
    PS-Parallel.ps1
.DESCRIPTION 
    Run multiple commands in parallel.
    There is overhead when stating powershell jobs, this command is only beneficial when the commands you specify are long running.
.EXAMPLE
    Get-Content command_list.txt | PS-Parallel.ps1
.NOTES 
    Authors    : Ryan Parker-Hill <ryanph@aspersion.net>, Andrew Van Slageren
.LINK 
    https://github.com/ryanph/PS-Parallel
#> 

Param
(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]    [string[]]$Commands,
    [Parameter(Mandatory=$false)]              [int] $MaxConcurrent = 3,
    [Parameter(Mandatory=$false)]              [int] $JobPollInterval = 5
)

Set-StrictMode -Version 3
$CommandList = [System.Collections.ArrayList]$Commands
if ( $input -is [array] ) {
    $CommandList = [System.Collections.ArrayList]$input
}
if ( ! $CommandList ) {
    Throw "Command list is empty"
}
filter timestamp {"$(Get-Date -Format s) $_"}
$JobPrefix = "PS-Parallel-"+$pid
$JobNameMap = @{}

Write-Output "Executing the $($CommandList.Count) specified commands $MaxConcurrent at a time" | timestamp

While ( $CommandList.Count -gt 0 -or $(get-job | ? {$_.Name -like "$($JobPrefix)_*"} | Measure-Object).count -gt 0 ) {

    get-job | ? {$_.Name -like "$($JobPrefix)*"} | Foreach-Object {
	    if( $_.State -eq "Running" ) {
		    return
	    }
        $JobCommand = $JobNameMap.Get_Item($_.Name)
        Write-Output "Job $($_.Name) ($JobCommand) completed at $($_.PSEndTime) (Duration $($_.PSEndTime - $_.PSBeginTime))" | timestamp
        Receive-Job $_.Id -ErrorAction "SilentlyContinue" 
		Remove-Job $_.Id -WhatIf:$false
    }

    
    while ( $(get-job -state Running | ? {$_.Name -like "$($JobPrefix)_*"} | Measure-Object).count -lt $MaxConcurrent -and $CommandList.Count -gt 0 ) {
        
        $Command = $CommandList[0]
        $CommandList.Remove($Command)

        if ( $Command ) {
            $JobName = "$($JobPrefix)_$($CommandList.Count)"
            $JobNameMap.Set_Item($JobName, $Command)
            Write-Output "Starting job $JobName with command $Command" | timestamp
            $job = Start-Job -Name $JobName -ScriptBlock { Invoke-Expression $args[0] } -ArgumentList $Command
        }
    }

    Start-Sleep -s $JobPollInterval

}


