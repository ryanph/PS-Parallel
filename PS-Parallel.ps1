<# 
.SYNOPSIS 
    PS-Parallel.ps1
.DESCRIPTION 
    Run multiple commands in parallel.
    Commands are accepted as a piplined array, or as a text file with one command per line.
    There is overhead when stating powershell jobs, this command is only beneficial when the commands you specify are long running.
.EXAMPLE

    # Execute commands in cmds.txt in parallel
    Get-Content cmds.txt | PS-Parallel.ps1
    PS-Parallel -Commands cmds.txt

    # Exectue commands in cmds.txt forever without running duplicate commands
    PS-Parallel -Commands cmds.txt -RepeatForever

    # Execute commands in cmds.txt forever and reload the command list
    PS-Parallel -Commands cmds.txt -ReloadCommmandFile -RepeatForever

.NOTES 
    Authors    : Ryan Parker-Hill <ryanph@aspersion.net>
.LINK 
    https://github.com/ryanph/PS-Parallel
#> 

Param
(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)] [String[]]$Commands,
    [Parameter(Mandatory=$false)] [int] $MaxConcurrent = 3,
    [Parameter(Mandatory=$false)] [int] $JobPollInterval = 5,
    [Parameter(Mandatory=$false)] [switch] $RepeatForever = $false,
    [Parameter(Mandatory=$false)] [switch] $ReloadCommmandFile = $false
)

Set-StrictMode -Version 3
filter timestamp {"$(Get-Date -Format s) $_"}

$JobPrefix = "PS-Parallel-"+$pid
$JobNameMap = @{}

Function Get-CommandList {
    if ( $input -is [array] -and $input.Count -gt 1 ) {
        if ( $ReloadCommmandFile ) {
            Throw "Cannot reload command file when input is pipelined"
        }
        return $input.Clone()
    } elseif ( $Commands -is [array] -and $Commands.Count -gt 1 ) {
        if ( $ReloadCommmandFile ) {
            Throw "Cannot reload command file when input is specified as an array parameter"
        }
        return $Commands.Clone()
    } elseif ( $Commands -is [array] -and $Commands.Count -eq 1 ) {
        return $(Get-Content $Commands[0])
    } else {
        Throw "No command list or file specified"
    }
}

$CommandQueue = [System.Collections.ArrayList] $(Get-CommandList)
Write-Output "Executing the $($CommandQueue.Count) specified commands $MaxConcurrent at a time" | timestamp
$JobNumber = 0

# Loop while jobs are present or commands are in the list
While ( $CommandQueue.Count -gt 0 -or $(get-job | ? {$_.Name -like "$($JobPrefix)_*"} | Measure-Object).count -gt 0 ) {

    # Handle completed jobs
    get-job | ? {$_.Name -like "$($JobPrefix)*"} | Foreach-Object {
        if( $_.State -eq "Running" ) {
            return
        }
        $JobCommand = $JobNameMap.Get_Item($_.Name)
        Write-Output "Job Complete $($_.Name): $JobCommand" | timestamp
        Write-Output "  Finished at $($_.PSEndTime) after $($_.PSEndTime - $_.PSBeginTime)" | timestamp
        Receive-Job $_.Id -ErrorAction "SilentlyContinue"
        Remove-Job $_.Id -WhatIf:$false
    }

    # Fire off new jobs
    while ( $(get-job -state Running | ? {$_.Name -like "$($JobPrefix)_*"} | Measure-Object).count -lt $MaxConcurrent -and $CommandQueue.Count -gt 0 ) {
        
        $Command = $CommandQueue[0]
        $CommandQueue.Remove($Command)

        if ( $Command ) {
            $JobNumber = $JobNumber + 1
            $JobName = "$($JobPrefix)_$($JobNumber)"
            $JobNameMap.Set_Item($JobName, $Command)
            Write-Output "Job Start $($JobName): $Command" | timestamp
            $job = Start-Job -Name $JobName -ScriptBlock { Invoke-Expression $args[0] } -ArgumentList $Command
        }
    }

    # Repopulate the CommandQueue
    if ( $CommandQueue.Count -eq 0 -and $RepeatForever -and $(get-job -state Running | ? {$_.Name -like "$($JobPrefix)_*"} | Measure-Object).count -lt $MaxConcurrent) {

        Write-Output "All queued jobs have executed. Populating command queue." | timestamp
        $CommandQueue = [System.Collections.ArrayList] $(Get-CommandList)

        foreach ( $RunningCommand in $(get-job -state Running | Select -Property Name) ) {
            if ( $CommandQueue.Contains($JobNameMap[$RunningCommand.Name]) ) {
                Write-Output "  Not re-queueing running command: $($JobNameMap[$RunningCommand.Name])" | timestamp
                $CommandQueue.Remove($JobNameMap[$RunningCommand.Name])
            }
        }
    }

    Start-Sleep -s $JobPollInterval

}

