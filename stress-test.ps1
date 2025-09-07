# stress-test.ps1 - Stress test for limits checking

param(
    [string]$BaseUrl = "http://arch.homework",
    [int]$Duration = 600,      # 10 minutes
    [int]$Users = 50           # 50 virtual users
)

# Load functions from load-test.ps1
. $PSScriptRoot\load-test.ps1

# Run with increased parameters
Run-Load-Test -Duration $Duration -Users $Users -BaseUrl $BaseUrl