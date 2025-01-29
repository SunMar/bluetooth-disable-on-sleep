# Bluetooth.ps1

## Description

This script configures the computer to automatically disable Bluetooth when the computer goes to sleep, and enables Bluetooth again when it wakes.

It uses PowerShell to install two tasks in the Task Scheduler. The tasks trigger on Kernel Power events that signal the computer is entering and exiting Modern Standby.

The original PowerShell code to change the Bluetooth state was written by [u/mkdr](https://www.reddit.com/user/mkdr/) and shared in a reply on [Laptop in sleep mode but bluetooth still on???](https://www.reddit.com/r/Dell/comments/qmm90f/laptop_in_sleep_mode_but_bluetooth_still_on/). This script expands on that and adds a few quality of life features like an automated (un)install of the Task Scheduler tasks.

### Limitations

> [!IMPORTANT]
> Your mileage may vary. It's possible the computer enters sleep before the task disables Bluetooth. If that happens, your computer will, unfortunately, have Bluetooth enabled during sleep.
> In my experience, Bluetooth will usually still turn off within a few minutes.
> If Bluetooth was still on when waking, it's possible it will then turn off and on again. Sometimes it will stay off after waking, requiring you to enable Bluetooth manually again.
> Don't expect a perfect solution that works consistently.

## Features

* Disable and enable Bluetooth automatically on sleep and wake via tasks in Task Scheduler.
* Install and Remove actions for automated management of the Task Scheduler tasks.
* Installed tasks will trigger on entering and exiting Modern Standby (but remember the [limitations](#limitations)).
* Tasks run as `SYSTEM` user with administrative privileges.
* Requests administrative privileges if started without them.
* Interactive menu if started without specifying an action.
* Show usage information if started with an invalid action.

## Requirements

* Windows 10 / 11
* PowerShell 5.1 _(comes pre-installed with Windows)_
* Modern Standby _(if you're using legacy S3 sleep states you probably don't need this script)_
* An [execution policy](#execution-policy) that allows running scripts

## Execution Policy

> [!CAUTION]
> Running PowerShell scripts is a big security risk. You should never run scripts you download from the internet unless you're 100% sure they're safe. Even enabling the ability to run scripts will reduce the security of your computer. Running this script and enabling the ability to run scripts is at your own risk!

By default Windows does not allow the execution of PowerShell scripts.
To run scripts you need to change the [Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1).

You can see the current execution policy by running in a PowerShell: `Get-ExecutionPolicy -Scope CurrentUser`

The execution policy `RemoteSigned` allows running scripts. It can be set by running in a PowerShell: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## Usage

### First use

1. Make sure your [execution policy](#execution-policy) allows running PowerShell scripts.
2. Download [Bluetooth.ps1](https://github.com/SunMar/bluetooth-disable-on-sleep/blob/main/Bluetooth.ps1) (make sure to save it as a `.ps1` file).
3. Copy it to a permanent location (e.g. your home directory `%USERPROFILE%` or `C:\`, anywhere where it won't be deleted).
4. Use Explorer to navigate to the folder where you copied it to.
5. Right-click the file, choose `Properties`, and at the bottom in the `Security` section check `[x] Unblock` and click `OK`.
6. Right-click the file again and choose `Run with PowerShell`.
7. Allow administrative privileges when asked.
8. Choose `Install` (or any other action you want).
9. Done, the script is now active (but remember the [limitations](#limitations)).

### Subsequent use

If you want to run the script again in the future, use Explorer to navigate to the folder where you copied it to.
Right-click the file and choose `Run with PowerShell`.

### Uninstall and deletion

> [!WARNING]
> If you want to delete the `Bluetooth.ps1` file, do not forget to first run the script and select `Uninstall` to remove the tasks in Task Scheduler.
> After uninstalling the tasks you can remove the `Bluetooth.ps1` file from your computer.
