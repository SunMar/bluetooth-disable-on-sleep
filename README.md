# Bluetooth.ps1

## Description

This script configures the computer to automatically disable Bluetooth when the computer goes to sleep, and enables Bluetooth again when it wakes.

It uses PowerShell to install two tasks in the Task Scheduler. The tasks trigger on Kernel Power events that signal the computer is entering and exiting Modern Standby.

The original PowerShell code to change the Bluetooth state was written by [u/mkdr](https://www.reddit.com/user/mkdr/) and shared in a reply on [Laptop in sleep mode but bluetooth still on???](https://www.reddit.com/r/Dell/comments/qmm90f/laptop_in_sleep_mode_but_bluetooth_still_on/). This script expands on that and adds a few quality of life features like an automated (un)install of the Task Scheduler tasks.

## Disclaimer

> [!IMPORTANT]
> Your mileage may vary. It's possible the computer enters sleep before the task manages to disable Bluetooth. If that happens, your computer will, unfortunately, have Bluetooth enabled during sleep. Bluetooth usually then turns off and on again when waking, but also sometimes stays off and needs to be manually enabled again.

## Requirements

* Windows 10 / 11
* PowerShell 5.1 _(comes pre-installed with Windows)_
* Modern Standby _(if you're using legacy S3 sleep states you probably don't need this script)_

## Usage

1. Download [Bluetooth.ps1](https://github.com/SunMar/bluetooth-disable-on-sleep/blob/main/Bluetooth.ps1) (make sure to save it as a `.ps1` file).
2. Copy it to a permanent location (e.g. your home directory `%USERPROFILE%` or `C:\`, anywhere where it won't be deleted).
3. Use Explorer and find it in the folder from step 2 where you copied it to permanently.
4. Right-click the file and choose `Run with PowerShell`.
5. Allow administrative privileges when asked.
6. Choose `Install` (or any other action you want).
7. Done, the script is now active (but remember the [Disclaimer](#disclaimer)).

> [!CAUTION]
> If you want to delete the `Bluetooth.ps1` file, do not forget to first run the script and select `Uninstall` to remove the tasks in Task Scheduler.

## Features

* Disable and enable Bluetooth automatically on sleep and wake via tasks in Task Scheduler.
* Install and Remove actions for automated management of the Task Scheduler tasks.
* Installed tasks trigger on entering and exiting Modern Standby (but remember the [Disclaimer](#disclaimer)).
* Tasks run as `SYSTEM` user with administrative privileges.
* Requests administrative privileges if started without them.
* Interactive menu if started without specifying an action.
* Show usage information if started with an invalid action.
