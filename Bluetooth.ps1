# https://github.com/SunMar/bluetooth-disable-on-sleep
param(
    [string]$Action
)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $Arguments = @(
        '-NoLogo',
        '-NoProfile',
        '-File',
        "`"$PSCommandPath`""
    )

    if ([string]::IsNullOrEmpty($Action) -eq $false) {
        $Arguments += $Action
    }

    Start-Process -Verb RunAs PowerShell -ArgumentList @($Arguments)
    exit 0
}

function Show-Usage {
    Write-Host ''
    Write-Host "Usage: `"$($MyInvocation.ScriptName)`" [Action]"
    Write-Host ''

    Write-Host 'Actions:'
    Write-Host ''

    $Actions = Get-Actions

    $MaxLength = ($Actions.Values | ForEach-Object { $_ | Where-Object { $_.Type -eq 'Action' } | ForEach-Object { $_.Action.Length } } | Measure-Object -Maximum).Maximum

    foreach ($Menu in $Actions.Values) {
        foreach ($Action in $Menu) {
            if ($Action.Type -eq 'Action') {
                Write-Host "  $($Action.Action.PadRight($MaxLength)) : $($Action.Description)"
            }
        }
    }

    Write-Host ''
}

function Show-Description {
    Write-Host 'This script configures the computer to automatically disable Bluetooth when'
    Write-Host 'the computer goes to sleep, and enables Bluetooth again when it wakes.'
    Write-Host ''
}

function Get-Actions {
    return [ordered]@{
        'Main' = @(
            @{
                'Type' = 'Action'
                'Action' = 'Install'
                'Name' = 'Install'
                'Description' = 'Create tasks in Task Scheduler'
            },
            @{
                'Type' = 'Action'
                'Action' = 'Uninstall'
                'Name' = 'Uninstall'
                'Description' = 'Delete tasks from Task Scheduler'
            }
        )
        'Bluetooth' = @(
            @{
                'Type' = 'Action'
                'Action' = 'On'
                'Name' = 'Enable'
                'Description' = 'Turn Bluetooth on'
            },
            @{
                'Type' = 'Action'
                'Action' = 'Off'
                'Name' = 'Disable'
                'Description' = 'Turn Bluetooth off'
            }
        )
    }
}

function Get-ModernStandby-Tasks {
    return @(
        @{
            'Name' = 'Bluetooth - Disable on sleep'
            'EventID' = 506
            'State' = 'Off'
        },
        @{
            'Name' = 'Bluetooth - Enable on wake'
            'EventID' = 507
            'State' = 'On'
        }
    )
}

function Select-Action {
    $Actions = Get-Actions
    $Menu = 'Main'
    $CurrentIndex = 0

    :menu while ($true) {
        $MenuActions = $Actions[$Menu]

        if ($Menu -ne 'Main') {
            $MenuActions += @{
                'Type' = 'Menu'
                'Action' = 'Main'
                'Name' = 'Back'
                'Description' = 'Back to main menu.'
            }
        }

        $MenuActions += @{
            'Type' = 'Exit'
            'Action' = 'Exit'
            'Name' = 'Exit'
            'Description' = 'Exit the script.'
        }

        Write-Output "$([char]27)[H$([char]27)[2J"

        Show-Description

        Write-Host "  $Menu Menu"
        Write-Host ''

        [Console]::CursorVisible = $false

        Show-Menu -Actions $MenuActions -NavigationBreak $Actions[$Menu].Count -Selected $CurrentIndex

        $Key = $null

        :selection while ($Key -ne 'Enter') {
            $Key = [Console]::ReadKey($true).Key

            switch ($Key) {
                'UpArrow' {
                    if ($CurrentIndex -gt 0) {
                        $CurrentIndex--
                    }
                }
                'DownArrow' {
                    if ($CurrentIndex -lt ($MenuActions.Count - 1)) {
                        $CurrentIndex++
                    }
                }
                default {
                    continue selection
                }
            }

            Show-Menu -Actions $MenuActions -NavigationBreak $Actions[$Menu].Count -Selected $CurrentIndex -ResetPosition
        }

        switch ($MenuActions[$CurrentIndex].Type) {
            'Action' {
                [Console]::CursorVisible = $true

                Write-Host ''

                Handle-Action -Action $MenuActions[$CurrentIndex].Action

                [Console]::CursorVisible = $false
                Write-Host ''
                Write-Host -NoNewline 'Press any key to continue ...'
                [Console]::ReadKey($true) | Out-Null
            }
            'Menu' {
                $Menu = $MenuActions[$CurrentIndex].Action
                $CurrentIndex = 0
            }
            'Exit' {
                [Console]::CursorVisible = $true

                Write-Host ''

                break menu
            }
        }
    }
}

function Show-Menu {
    param(
        [Parameter(Mandatory = $true)] [hashtable[]]$Actions,
        [Parameter(Mandatory = $true)] [int]$NavigationBreak,
        [int]$Selected = 0,
        [switch]$ResetPosition
    )

    if ($ResetPosition.IsPresent) {
        [Console]::SetCursorPosition(0, ([Console]::CursorTop - $Actions.Count - 1))
    }

    $MaxLength = (($Actions | ForEach-Object { $_.Name.Length }) | Measure-Object -Maximum).Maximum

    for ($i = 0; $i -lt $Actions.Count; $i++) {
        if ($i -eq $Selected) {
            $fgColor = [Console]::BackgroundColor
            $bgColor = [Console]::ForegroundColor
        } else {
            $fgColor = [Console]::ForegroundColor
            $bgColor = [Console]::BackgroundColor
        }

        if ($i -eq $NavigationBreak) {
            Write-Host ''
        }

        Write-Host -NoNewline '  '
        Write-Host -NoNewline -ForegroundColor $fgColor -BackgroundColor $bgColor $Actions[$i].Name
        Write-Host "$(''.PadLeft($MaxLength - $Actions[$i].Name.Length)) : $($Actions[$i].Description)"
    }
}

function Install-ScheduledTasks {
    foreach ($task in Get-ModernStandby-Tasks) {
        $trigger = New-CimInstance -ClientOnly -CimClass (Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler)
        $trigger.Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=$($task['EventID'])]]</Select></Query></QueryList>"
        $trigger.Enabled = $true

        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Unrestricted -WindowStyle Hidden -File `"$PSCommandPath`" $($task['State'])"

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit '00:01'

        Register-ScheduledTask -TaskName $task['Name'] -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force -User 'NT AUTHORITY\SYSTEM'
    }
}

function Uninstall-ScheduledTasks {
    param(
        [switch]$NotifyNoTasks
    )

    $deleted = $false

    Write-Host ''

    foreach ($task in Get-ModernStandby-Tasks) {
        if (Get-ScheduledTask -TaskName $task['Name'] -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $task['Name'] -Confirm:$false
            Write-Host "Deleted task `"$($task['Name'])`"."
            $deleted = $true
        }
    }

    if ($deleted -eq $false -and $NotifyNoTasks.IsPresent) {
        Write-Host 'No tasks to remove.'
        Write-Host ''
    }
}

function Invoke-BluetoothSetState {
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('On', 'Off')] [string]$State
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

function Handle-Action {
    param(
        [Parameter(Mandatory = $true)] [string]$Action
    )

    switch ($Action) {
        {$_ -in 'On', 'Off'} {
            Invoke-BluetoothSetState -State $Action

            Write-Host ''
            Write-Host "Bluetooth is now set to: $Action"
            Write-Host ''
        }
        'Install' {
            Uninstall-ScheduledTasks
            Install-ScheduledTasks

            Write-Host ''
            Write-Host 'All tasks have been installed.'
        }
        'Uninstall' {
            Uninstall-ScheduledTasks -NotifyNoTasks
        }
        default {
            Show-Usage
            exit 1
        }
    }
}

if ([string]::IsNullOrEmpty($Action)) {
    Select-Action
} else {
    Handle-Action -Action $Action
}
