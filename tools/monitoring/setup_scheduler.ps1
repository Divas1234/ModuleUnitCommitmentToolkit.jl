# Register Windows Scheduled Task for PCM Progress Email Notifier
# Runs daily every 3 hours between 08:00 and 20:00 (08:00, 11:00, 14:00, 17:00, 20:00)

$TaskName = "PCM_Progress_Email_Notifier"
$ScriptPath = "D:\GithubClonefiles\module_unitcommitment\tools\monitoring\send_progress_email.py"
$PythonPath = (Get-Command python).Source

Write-Host "Registering Scheduled Task: $TaskName"
Write-Host "Python Path: $PythonPath"
Write-Host "Script Path: $ScriptPath"

# Trigger: Daily starting at 08:00, repeating every 3 hours for 12 hours (08:00, 11:00, 14:00, 17:00, 20:00)
$Trigger = New-ScheduledTaskTrigger -Daily -At 08:00
$Trigger.RepetitionInterval = (New-TimeSpan -Hours 3)
$Trigger.RepetitionDuration = (New-TimeSpan -Hours 13)

# Action: Run Python script
$Action = New-ScheduledTaskAction -Execute $PythonPath -Argument "`"$ScriptPath`""

# Settings: Allow on battery, don't stop if running
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# Unregister if already exists
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Register task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Periodic PCM benchmark progress reporter to email"

Write-Host "`nTask successfully registered! It will run daily at 08:00, 11:00, 14:00, 17:00, 20:00."
