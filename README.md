# macOS Volume Limiter Daemon

This is a simple background daemon for macOS that ensures the system's output volume does not exceed a specified
percentage.

## Features

* Runs silently in the background.

* Configurable via a simple command-line interface.

* Constantly monitors and adjusts the volume if it exceeds the set limit.

* Built with Go and configured to run as a launchd agent.

## How It Works

The system consists of three main parts:

1. `volume_limiter` (Go program): A command-line application that can either run in `daemon` mode to continuously
   monitor volume or be used with the -p flag to set a new volume limit. It uses `osascript` (AppleScript) to get and
   set the system volume.

2. `com.user.volumelimiter.plist` (launchd file): This configuration file tells macOS's `launchd` service how to run the
   `volume_limiter` program as a background agent for the current user. It ensures the program is always running.

3. `install.sh` (Installer): A script that automates the entire setup process: compiling the Go code, moving the
   executable to `/usr/local/bin`, and configuring `launchd`.

## Installation

1. Save the Files: Make sure `volume_limiter.go`, `com.user.volumelimiter.plist`, and `install.sh` are all in the same
   directory.

2. Make the Installer Executable: Open your terminal, navigate to the directory where you saved the files, and run:

    ```shell
    chmod +x install.sh
    ```

3. Run the Installer: Execute the installation script. You may be prompted for your password to move the compiled
   program into /usr/local/bin.

    ```shell
    
    ./install.sh
    ```

The script will handle compilation, file placement, and loading the background service.

## Usage

Once installed, you can set the volume limit from your terminal at any time.

To set a volume limit:

Use the -p or --percentage flag followed by a number between 0 and 100.

* Limit volume to 75%:

    ```shell
    volume_limiter -p 75
    ```

* Limit volume to 50%:

    ```shell
    volume_limiter -p 50
    ```

The daemon, running in the background, will automatically pick up this new value and enforce it. If you manually raise
the volume above the set limit, the daemon will reduce it back down within a second.

## Troubleshooting

* Check Logs: The daemon's activity and any potential errors are logged.
    * Activity Log: `/tmp/volume_limiter.log`
    * Error Log: `/tmp/volume_limiter_error.log`

* Check if the Daemon is Running:
    ```shell
    launchctl list | grep volumelimiter
    ```

If you see a line with `com.user.volumelimiter`, the agent is loaded.

## Uninstallation

To completely remove the volume limiter:

1. Unload the Daemon:

    ```shell
   launchctl unload ~/Library/LaunchAgents/com.user.volumelimiter.plist
    ```

2. Remove Files:
    ```shell
    rm ~/Library/LaunchAgents/com.user.volumelimiter.plist
    sudo rm /usr/local/bin/volume_limiter
    rm /tmp/volume_limiter_percentage.conf
    rm /tmp/volume_limiter.log
    rm /tmp/volume_limiter_error.log
    ```