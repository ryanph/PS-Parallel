# PS-Parallel

Run a list of commands in parallel (like GNU Parallel).

Commands are accepted as a piplined array, or as a text file with one command per line.

The overhead in starting Powershell jobs for each command makes this only really benficial when you have a lot of long running commands you want to get through.

By default executes 3 commands at a time.

## Examples
### Execute commands in cmds.txt in parallel
- Get-Content cmds.txt | PS-Parallel.ps1
- Get-Content cmds.txt | PS-Parallel.ps1 -MaxConcurrent 10
- PS-Parallel -Commands cmds.txt

### Exectue commands in cmds.txt repeatedly (without running twice at the same time)
- PS-Parallel -Commands cmds.txt -RepeatForever
- Get-Content cmds.txt | PS-Parallel.ps1 -RepeatForever

### Same as above but check the command file for new commands as well
- PS-Parallel -Commands cmds.txt -ReloadCommmandFile -RepeatForever

## Contribute
Please, my powershell is terrible.
