# PS-Parallel

Run a list of commands in parallel (like GNU Parallel).

The overhead in starting Powershell jobs for each command makes this only really benficial when you have a lot of long running commands you want to get through.

By default execute 3 commands at a time.

## Examples
- Get-Content command_list.txt | PS-Parallel.ps1
- Get-Content command_list.txt | PS-Parallel.ps1 -MaxConcurrent 10

## Contribute
Please, my powershell is terrible.
