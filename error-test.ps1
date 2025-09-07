# error-test.ps1 - Error case testing for OTUS application

param(
    [int]$Duration = 1200,      # Test duration in seconds
    [int]$Users = 5,           # Number of virtual users
    [string]$BaseUrl = "http://arch.homework"
)

function Write-Colored {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Endpoint {
    param([string]$Url, [string]$Method = "GET", [string]$Body = $null, [hashtable]$Headers = @{})

    try {
        $defaultHeaders = @{
            "Content-Type" = "application/json"
        }

        $allHeaders = $defaultHeaders + $Headers
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $requestParams = @{
            Uri = $Url
            Method = $Method
            Headers = $allHeaders
            ErrorAction = 'Stop'
        }

        if ($Body) {
            $requestParams.Body = $Body
        }

        $response = Invoke-WebRequest @requestParams
        $stopwatch.Stop()

        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Content = $response.Content
        }
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.Value__ } else { 0 }
        return @{
            Success = $false
            StatusCode = $statusCode
            Error = $_.Exception.Message
            ResponseTime = if ($stopwatch) { $stopwatch.ElapsedMilliseconds } else { 0 }
        }
    }
}

function Test-Error-Scenarios {
    $errorScenarios = @(
        # Application errors
        @{Name = "500 endpoint"; Url = "/error"; Method = "GET"; ExpectedCode = 500},
        @{Name = "Non-existent endpoint"; Url = "/nonexistent-endpoint"; Method = "GET"; ExpectedCode = 404},
        @{Name = "Invalid user ID"; Url = "/api/v1/user/invalid-id"; Method = "GET"; ExpectedCode = 400},
        @{Name = "Invalid JSON"; Url = "/api/v1/user"; Method = "POST"; Body = '{"invalid": "json"'; ExpectedCode = 400},
        @{Name = "Empty JSON"; Url = "/api/v1/user"; Method = "POST"; Body = '{}'; ExpectedCode = 400},
        @{Name = "Wrong method health"; Url = "/health"; Method = "POST"; ExpectedCode = 405},
        @{Name = "Delete non-existent"; Url = "/api/v1/user/999999"; Method = "DELETE"; ExpectedCode = 404},

        # NGINX errors
        @{Name = "Non-existent page"; Url = "/nonexistent-page.html"; Method = "GET"; ExpectedCode = 404},
        @{Name = "Invalid API endpoint"; Url = "/api/v1/invalid-endpoint"; Method = "GET"; ExpectedCode = 404},
        @{Name = "Wrong method API"; Url = "/api/v1/user"; Method = "PUT"; ExpectedCode = 405},
        @{Name = "Very long URL"; Url = "/very-long-url-" + ("x" * 1000); Method = "GET"; ExpectedCode = 414},
        @{Name = "Large payload"; Url = "/api/v1/user"; Method = "POST"; Body = ('{"large": "' + ("x" * 10000) + '"}'); ExpectedCode = 413}
    )

    $results = @()

    foreach ($scenario in $errorScenarios) {
        Write-Host "Testing: $($scenario.Name)" -ForegroundColor Cyan
        $result = Test-Endpoint -Url "$BaseUrl$($scenario.Url)" -Method $scenario.Method -Body $scenario.Body

        $status = if ($result.Success) { "UNEXPECTED SUCCESS" }
                 elseif ($result.StatusCode -eq $scenario.ExpectedCode) { "EXPECTED ERROR" }
                 else { "WRONG ERROR CODE" }

        $color = switch ($status) {
            "EXPECTED ERROR" { "Green" }
            "WRONG ERROR CODE" { "Yellow" }
            "UNEXPECTED SUCCESS" { "Red" }
        }

        $results += [PSCustomObject]@{
            Scenario = $scenario.Name
            URL = $scenario.Url
            Method = $scenario.Method
            Expected = $scenario.ExpectedCode
            Actual = if ($result.Success) { "200" } else { $result.StatusCode }
            Status = $status
            ResponseTime = if ($result.Success) { "$($result.ResponseTime)ms" } else { "$($result.ResponseTime)ms" }
        }

        Write-Host "Scenario: $($scenario.Name)  Status: $status (Expected: $($scenario.ExpectedCode), Got: $(if ($result.Success) {'200'} else {$result.StatusCode}))" -ForegroundColor $color
        Start-Sleep -Milliseconds 100
    }

    return $results
}

function Run-Error-Test {
    Write-Colored "=== ERROR CASE TESTING ===" "Green"
    Write-Colored "Base URL: $BaseUrl" "Yellow"
    Write-Colored "Duration: $Duration seconds" "Yellow"
    Write-Colored "Start time: $(Get-Date)" "Yellow"

    $results = Test-Error-Scenarios

    Write-Colored "`n=== TEST RESULTS ===" "Green"
    $summary = $results | Group-Object Status

    foreach ($group in $summary) {
        $color = switch ($group.Name) {
            "EXPECTED ERROR" { "Green" }
            "WRONG ERROR CODE" { "Yellow" }
            "UNEXPECTED SUCCESS" { "Red" }
        }

        Write-Host "$($group.Name): $($group.Count)/$($results.Count)" -ForegroundColor $color
    }

    Write-Colored "`nDetailed results:" "Green"
    $results | Format-Table -AutoSize

    return $results
}

# Load functions from load-test.ps1
. .\load-test.ps1
Run-Error-Test