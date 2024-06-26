# https://github.com/SunMar/bluetooth-disable-on-sleep
param(
    [string]$Action,
    [switch]$PauseBeforeExit
)

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $Arguments = @(
        "-NoLogo",
        "-NoProfile",
        "-File",
        "`"$PSCommandPath`"",
        "-PauseBeforeExit"
    )

    if (![string]::IsNullOrEmpty($Action)) {
        $Arguments += $Action
    }

    Start-Process -Verb RunAs PowerShell -ArgumentList @($Arguments)
    exit 0
}

function Show-Usage {
    $scriptName = $MyInvocation.ScriptName
    $actions = Get-Actions
    $keys = $actions.Keys -join "|"

    Write-Host ""
    Write-Host "Usage: `"$scriptName`" [-PauseBeforeExit] [$keys]"
    Show-Description

    Write-Host "Actions:"
    Write-Host ""

    $maxLength = ($actions.Keys | ForEach-Object { $_.Length }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

    foreach ($action in $actions.GetEnumerator()) {
        Write-Host "  $($action.Key.PadRight($maxLength)) : $($action.Value)"
    }
}

function Show-Description {
    Write-Host ""
    Write-Host "This script configures the computer to automatically disable Bluetooth when"
    Write-Host "the computer goes to sleep, and enables Bluetooth again when it wakes."
    Write-Host ""
}

function Get-Actions {
    $actions = New-Object System.Collections.Specialized.OrderedDictionary

    $actions.Add("Install", "Create tasks in Task Scheduler")
    $actions.Add("Uninstall", "Delete tasks from Task Scheduler")
    $actions.Add("On", "Enable Bluetooth")
    $actions.Add("Off", "Disable Bluetooth")

    return $actions
}

function Get-Tasks {
    return @(
        @{
            "Name" = "Bluetooth - Disable on sleep"
            "EventID" = 506
            "State" = "Off"
        },
        @{
            "Name" = "Bluetooth - Enable on wake"
            "EventID" = 507
            "State" = "On"
        }
    )
}

function Select-Action {
    $actions = Get-Actions
    $actions.Add("Exit", "Exit the script")

    Show-Description
    Write-Host "Please select an action:"
    Write-Host ""

    [Console]::CursorVisible = $false

    Show-Menu -Actions $actions

    $currentIndex = 0
    $key = $null

    :selection while ($key -ne "Enter") {
        $key = [Console]::ReadKey($true).Key

        switch ($key) {
            "UpArrow" {
                if ($currentIndex -gt 0) {
                    $currentIndex--
                }
            }
            "DownArrow" {
                if ($currentIndex -lt ($actions.Count - 1)) {
                    $currentIndex++
                }
            }
            default {
                continue selection
            }
        }

        Show-Menu -Actions $actions -Selected $currentIndex -ResetPosition
    }

    [Console]::CursorVisible = $true

    Write-Host ""

    return @($actions.Keys)[$currentIndex]
}

function Show-Menu {
    param(
        [Parameter(Mandatory = $true)] [System.Collections.Specialized.OrderedDictionary]$Actions,
        [int]$Selected = 0,
        [switch]$ResetPosition
    )

    if ($ResetPosition.IsPresent) {
        [Console]::SetCursorPosition(0, ([Console]::CursorTop - $Actions.Count))
    }

    $maxLength = ($Actions.Keys | ForEach-Object { $_.Length }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

    for ($i = 0; $i -lt $Actions.Count; $i++) {
        if ($i -eq $Selected) {
            $fgColor = [Console]::BackgroundColor
            $bgColor = [Console]::ForegroundColor
        } else {
            $fgColor = [Console]::ForegroundColor
            $bgColor = [Console]::BackgroundColor
        }

        $key = @($Actions.Keys)[$i]

        Write-Host -NoNewline "  "
        Write-Host -NoNewline -ForegroundColor $fgColor -BackgroundColor $bgColor $key
        Write-Host "$(''.PadRight($maxLength - $key.Length)) : $($Actions[$i])"
    }
}

function Install-ScheduledTasks {
    foreach ($task in Get-Tasks) {
        $trigger = New-CimInstance -ClientOnly -CimClass (Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler)
        $trigger.Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=$($task['EventID'])]]</Select></Query></QueryList>"
        $trigger.Enabled = $true

        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Unrestricted -WindowStyle Hidden -File `"$PSCommandPath`" $($task['State'])"

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -ExecutionTimeLimit "00:01"

        Register-ScheduledTask -TaskName $task["Name"] -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force -User "NT AUTHORITY\SYSTEM"
    }
}

function Uninstall-ScheduledTasks {
    param(
        [switch]$NotifyNoTasks
    )

    $deleted = $false

    Write-Host ""

    foreach ($task in Get-Tasks) {
        if (Get-ScheduledTask -TaskName $task["Name"] -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $task["Name"] -Confirm:$false
            Write-Host "Deleted task `"$($task['Name'])`"."
            $deleted = $true
        }
    }

    if ($deleted -eq $false -and $NotifyNoTasks.IsPresent) {
        Write-Host "No tasks to remove."
        Write-Host ""
    }
}

function Invoke-BluetoothSetState {
    param(
        [Parameter(Mandatory = $true)] [ValidateSet("On", "Off")] [string]$State
    )

    if ((Get-Service bthserv).Status -eq 'Stopped') {
        Start-Service bthserv
    }

    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
    [Windows.Devices.Radios.RadioAccessStatus,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
    [Windows.Devices.Radios.RadioState,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null

    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]

    function Await($WinRtTask, $ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }

    Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null

    $radios = Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
    $bluetooth = $radios | Where-Object { $_.Kind -eq 'Bluetooth' }

    Await ($bluetooth.SetStateAsync($State)) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null
}

if ([string]::IsNullOrEmpty($Action)) {
    $Action = Select-Action
    $PauseBeforeExit = $true
}

$ReturnCode = 0

switch ($Action) {
    {$_ -in "On", "Off"} {
        Invoke-BluetoothSetState -State $Action

        Write-Host ""
        Write-Host "Bluetooth is now set to: $Action"
        Write-Host ""
    }
    "Install" {
        Uninstall-ScheduledTasks
        Install-ScheduledTasks

        Write-Host ""
        Write-Host "Tasks have been installed."
    }
    "Uninstall" {
        Uninstall-ScheduledTasks -NotifyNoTasks
    }
    "Exit" {
        $PauseBeforeExit = $false
    }
    default {
        Show-Usage
        $ReturnCode = 1
    }
}

if ($PauseBeforeExit.IsPresent) {
    [Console]::CursorVisible = $false
    Write-Host ""
    Write-Host -NoNewline "Press any key to exit ..."
    [Console]::ReadKey($true) | Out-Null
    [Console]::CursorVisible = $true
} else {
    Write-Host ""
}

exit $ReturnCode
