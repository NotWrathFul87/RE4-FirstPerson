[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'Stop.signal'),'stop')
Write-Output 'Stop requested. Wait for confirmation in the main window.'
