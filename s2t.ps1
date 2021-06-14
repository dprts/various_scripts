param(
    [Parameter(Mandatory = $true)]
    [string]$key,
    [Parameter(Mandatory = $true)]
    [string]$bucket
)

$env:GOOGLE_APPLICATION_CREDENTIALS="$key"

$token = gcloud auth application-default print-access-token
if($token -eq $null) {
    Write-Error "Enter correct credential file"  -ErrorAction Stop
}

$headers = @{ Authorization = "Bearer $token" }

$body = @{
    config = @{
        encoding = "FLAC"
        languageCode = "en-US"
        enableWordTimeOffsets = "false"
        enableAutomaticPunctuation = "true"
        model = "phone_call"
        useEnhanced = "true"
        diarizationConfig = @{
            enableSpeakerDiarization = "true"
        }
    }
    audio = @{
        uri = "$bucket"
    }
}

$json_body = ConvertTo-Json ($body)

try {
    $result = Invoke-WebRequest -Method Post -Headers $headers -ContentType: 'application/json; charset=utf-8' -Body $json_body -Uri 'https://speech.googleapis.com/v1/speech:longrunningrecognize' 
} catch {
    Write-Error "Something went wrong while executing API Call: $_" -ErrorAction Stop
}

$request_id = ConvertFrom-Json($result.Content)
Write-Host "Submitted job: $($request_id.name)"

$progress = Invoke-WebRequest -Method GET -Headers $headers -ContentType: 'application/json; charset=utf-8' -Uri "https://speech.googleapis.com/v1/operations/$($request_id.name)" 
$progress_json = ConvertFrom-Json($progress.Content)

while($($progress_json.metadata.progressPercent) -lt 100) {
    if ($($progress_json.metadata.progressPercent) -eq $null) {
        $I = 0
    } else {
        $I = $($progress_json.metadata.progressPercent)
    }

    $progress = Invoke-WebRequest -Method GET -Headers $headers -ContentType: 'application/json; charset=utf-8' -Uri "https://speech.googleapis.com/v1/operations/$($request_id.name)" 
    $progress_json = ConvertFrom-Json($progress.Content)
    # Write-Progress -Activity "Execution in progress" -Status "$I% Complete:" -PercentComplete $I
    Write-Host -NoNewLine "$I% "
    Start-Sleep -s 1
}

$done = Invoke-WebRequest -Method GET -Headers $headers -ContentType: 'application/json; charset=utf-8' -Uri "https://speech.googleapis.com/v1/operations/$($request_id.name)" 
$done.Content | Out-File "$($request_id.name).json"

Write-Host ".....File processing finished output written to: $($request_id.name).json"