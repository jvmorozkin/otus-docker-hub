# load-test.ps1 - Load test for OTUS application with error cases

param(
    [int]$Duration = 300,      # Test duration in seconds (5 minutes default)
    [int]$Users = 10,          # Number of virtual users
    [string]$BaseUrl = "http://arch.homework",
    [switch]$IncludeErrors = $true  # Include error test cases
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

        if ($Method -eq "GET") {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $allHeaders -ErrorAction Stop
        }
        else {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $allHeaders -Body $Body -ErrorAction Stop
        }

        $stopwatch.Stop()

        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Content = $response.Content
        }
    }
    catch {
        return @{
            Success = $false
            StatusCode = $_.Exception.Response.StatusCode.Value__
            Error = $_.Exception.Message
            ResponseTime = if ($stopwatch) { $stopwatch.ElapsedMilliseconds } else { 0 }
        }
    }
}

function Generate-Random-User {
    $id = Get-Random -Minimum 1000 -Maximum 9999
    $username = "user$id"
    $email = "$username@example.com"

    return @{
        id = $id
        username = $username
        firstName = "FirstName$id"
        lastName = "LastName$id"
        email = $email
        phone = "+7916$(Get-Random -Minimum 1000000 -Maximum 9999999)"
    } | ConvertTo-Json
}

function Generate-Error-Case {
    $caseType = Get-Random -Minimum 1 -Maximum 6

    switch ($caseType) {
        1 { return @{Url = "/nonexistent-endpoint"; Method = "GET"} }
        2 { return @{Url = "/api/v1/user/invalid-id"; Method = "GET"} }
        3 { return @{Url = "/api/v1/user"; Method = "POST"; Body = '{"invalid": "json"'} }
        4 { return @{Url = "/api/v1/user"; Method = "POST"; Body = '{}'} }
        5 { return @{Url = "/health"; Method = "POST"} } # Wrong method
        6 { return @{Url = "/api/v1/user/999999"; Method = "DELETE"} } # Delete non-existent
    }
}

function Generate-Nginx-Error-Case {
    $caseType = Get-Random -Minimum 1 -Maximum 5

    switch ($caseType) {
        1 { return @{Url = "/nonexistent-page.html"; Method = "GET"} }
        2 { return @{Url = "/api/v1/invalid-endpoint"; Method = "GET"} }
        3 { return @{Url = "/health"; Method = "PUT"} } # Wrong method
        4 { return @{Url = "/very-long-url-" + ("x" * 1000); Method = "GET"} }
        5 { return @{Url = "/api/v1/user"; Method = "POST"; Body = ('{"large": "' + ("x" * 10000) + '"}')} }
    }
}

function Run-Load-Test {
    Write-Colored "=== OTUS APPLICATION LOAD TEST ===" "Green"
    Write-Colored "Base URL: $BaseUrl" "Yellow"
    Write-Colored "Duration: $Duration seconds" "Yellow"
    Write-Colored "Virtual users: $Users" "Yellow"
    Write-Colored "Include error cases: $IncludeErrors" "Yellow"
    Write-Colored "Start time: $(Get-Date)" "Yellow"
    Write-Colored "=" * 50 "Green"

    $stats = @{
        TotalRequests = 0
        SuccessfulRequests = 0
        FailedRequests = 0
        TotalResponseTime = 0
        ErrorCases = 0
        NginxErrors = 0
        EndpointStats = @{}
    }

    $endTime = (Get-Date).AddSeconds($Duration)
    $userThreads = @()

    $userAction = {
        param($BaseUrl, $UserId, $EndTime, $IncludeErrors, $StatsRef)

        $localStats = @{
            Requests = 0
            Success = 0
            Failures = 0
            ResponseTime = 0
            ErrorCases = 0
            NginxErrors = 0
        }

        $userData = Generate-Random-User | ConvertFrom-Json
        $createdUserId = $null

        while ((Get-Date) -lt $EndTime) {
            $action = Get-Random -Minimum 1 -Maximum 100

            # 5% chance for error cases if enabled
            if ($IncludeErrors -and (Get-Random -Minimum 1 -Maximum 100) -le 5) {
                $errorType = Get-Random -Minimum 1 -Maximum 100

                if ($errorType -le 50) {
                    # Application error case
                    $errorCase = Generate-Error-Case
                    $result = Test-Endpoint -Url "$BaseUrl$($errorCase.Url)" -Method $errorCase.Method -Body $errorCase.Body
                    $endpoint = "error_app"
                    $localStats.ErrorCases++
                }
                else {
                    # NGINX error case
                    $errorCase = Generate-Nginx-Error-Case
                    $result = Test-Endpoint -Url "$BaseUrl$($errorCase.Url)" -Method $errorCase.Method -Body $errorCase.Body
                    $endpoint = "error_nginx"
                    $localStats.NginxErrors++
                }
            }
            else {
                # Normal operations
                try {
                    switch ($action) {
                        # Health check (25%)
                        { $_ -le 25 } {
                            $result = Test-Endpoint -Url "$BaseUrl/health" -Method "GET"
                            $endpoint = "health"
                        }

                        # Get user (20%)
                        { $_ -gt 25 -and $_ -le 45 } {
                            if ($createdUserId) {
                                $result = Test-Endpoint -Url "$BaseUrl/api/v1/user/$createdUserId" -Method "GET"
                                $endpoint = "get_user"
                            }
                            else {
                                $result = Test-Endpoint -Url "$BaseUrl/api/v1/user/$(Get-Random -Minimum 1 -Maximum 100)" -Method "GET"
                                $endpoint = "get_user_random"
                            }
                        }

                        # Create user (20%)
                        { $_ -gt 45 -and $_ -le 65 } {
                            $userJson = Generate-Random-User
                            $result = Test-Endpoint -Url "$BaseUrl/api/v1/user" -Method "POST" -Body $userJson
                            $endpoint = "create_user"

                            if ($result.Success) {
                                $responseData = $result.Content | ConvertFrom-Json
                                $createdUserId = $responseData.id
                            }
                        }

                        # Update user (15%)
                        { $_ -gt 65 -and $_ -le 80 } {
                            if ($createdUserId) {
                                $userJson = Generate-Random-User
                                $result = Test-Endpoint -Url "$BaseUrl/api/v1/user/$createdUserId" -Method "PUT" -Body $userJson
                                $endpoint = "update_user"
                            }
                            else {
                                continue
                            }
                        }

                        # Delete user (10%)
                        { $_ -gt 80 -and $_ -le 90 } {
                            if ($createdUserId) {
                                $result = Test-Endpoint -Url "$BaseUrl/api/v1/user/$createdUserId" -Method "DELETE"
                                $endpoint = "delete_user"
                                $createdUserId = $null
                            }
                            else {
                                continue
                            }
                        }

                        # Actuator endpoints (10%)
                        { $_ -gt 90 } {
                            $actuatorType = Get-Random -Minimum 1 -Maximum 3
                            switch ($actuatorType) {
                                1 { $result = Test-Endpoint -Url "$BaseUrl/actuator/health" -Method "GET"; $endpoint = "actuator_health" }
                                2 { $result = Test-Endpoint -Url "$BaseUrl/actuator/info" -Method "GET"; $endpoint = "actuator_info" }
                                3 { $result = Test-Endpoint -Url "$BaseUrl/actuator/prometheus" -Method "GET"; $endpoint = "actuator_prometheus" }
                            }
                        }
                    }
                }
                catch {
                    $result = @{Success = $false; StatusCode = 500}
                }
            }

            $localStats.Requests++
            if ($result.Success) {
                $localStats.Success++
                $localStats.ResponseTime += $result.ResponseTime
            }
            else {
                $localStats.Failures++
            }

            $delay = Get-Random -Minimum 50 -Maximum 300
            Start-Sleep -Milliseconds $delay
        }

        return $localStats
    }

    Write-Colored "Starting $Users virtual users..." "Cyan"

    for ($i = 1; $i -le $Users; $i++) {
        $job = Start-Job -ScriptBlock $userAction -ArgumentList $BaseUrl, $i, $endTime, $IncludeErrors, $stats
        $userThreads += $job
    }

    # Progress monitoring
    $progressInterval = 10
    $nextProgressUpdate = (Get-Date).AddSeconds($progressInterval)

    while ((Get-Date) -lt $endTime) {
        if ((Get-Date) -ge $nextProgressUpdate) {
            $elapsed = [int]($Duration - ($endTime - (Get-Date)).TotalSeconds)
            $percentComplete = ($elapsed / $Duration) * 100
            Write-Colored "Progress: $percentComplete% complete ($elapsed/$Duration sec)" "Magenta"
            $nextProgressUpdate = (Get-Date).AddSeconds($progressInterval)
        }
        Start-Sleep -Seconds 1
    }

    # Collect results
    Write-Colored "Test completed, gathering results..." "Cyan"

    $totalStats = @{
        TotalRequests = 0
        SuccessfulRequests = 0
        FailedRequests = 0
        TotalResponseTime = 0
        ErrorCases = 0
        NginxErrors = 0
    }

    foreach ($job in $userThreads) {
        $jobResult = Receive-Job -Job $job
        $totalStats.TotalRequests += $jobResult.Requests
        $totalStats.SuccessfulRequests += $jobResult.Success
        $totalStats.FailedRequests += $jobResult.Failures
        $totalStats.TotalResponseTime += $jobResult.ResponseTime
        $totalStats.ErrorCases += $jobResult.ErrorCases
        $totalStats.NginxErrors += $jobResult.NginxErrors
    }

    # Display results
    Write-Colored "=" * 60 "Green"
    Write-Colored "LOAD TEST RESULTS" "Green"
    Write-Colored "=" * 60 "Green"
    Write-Colored "Total time: $Duration seconds" "Yellow"
    Write-Colored "Virtual users: $Users" "Yellow"
    Write-Colored "Total requests: $($totalStats.TotalRequests)" "Yellow"
    Write-Colored "Successful requests: $($totalStats.SuccessfulRequests)" "Green"
    Write-Colored "Failed requests: $($totalStats.FailedRequests)" "Red"
    Write-Colored "Error test cases: $($totalStats.ErrorCases)" "Magenta"
    Write-Colored "NGINX error cases: $($totalStats.NginxErrors)" "Magenta"

    if ($totalStats.SuccessfulRequests -gt 0) {
        $avgResponseTime = [math]::Round($totalStats.TotalResponseTime / $totalStats.SuccessfulRequests, 2)
        $rps = [math]::Round($totalStats.SuccessfulRequests / $Duration, 2)
        $errorRate = [math]::Round(($totalStats.FailedRequests / $totalStats.TotalRequests) * 100, 2)

        Write-Colored "Average response time: ${avgResponseTime}ms" "Yellow"
        Write-Colored "RPS (requests per second): $rps" "Yellow"
        Write-Colored "Error rate: ${errorRate}%" "Yellow"
    }

    Write-Colored "End time: $(Get-Date)" "Yellow"
    Write-Colored "=" * 60 "Green"

    $userThreads | Remove-Job -Force
}

# Run test
try {
    Run-Load-Test
}
catch {
    Write-Colored "Error: $($_.Exception.Message)" "Red"
}
finally {
    Get-Job | Remove-Job -Force
}