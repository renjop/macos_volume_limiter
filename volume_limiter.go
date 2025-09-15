package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const (
	// The file path to store the desired volume limit percentage
	configFile = "/tmp/volume_limiter_percentage.conf"
)

// getVolume retrieves the current system output volume.
// It executes an AppleScript command via osascript.
func getVolume() (int, error) {
	cmd := exec.Command("osascript", "-e", "output volume of (get volume settings)")
	output, err := cmd.Output()
	if err != nil {
		return 0, fmt.Errorf("failed to get volume: %w", err)
	}

	volumeStr := strings.TrimSpace(string(output))
	volume, err := strconv.Atoi(volumeStr)
	if err != nil {
		return 0, fmt.Errorf("failed to parse volume: %w", err)
	}
	return volume, nil
}

// setVolume sets the system output volume to a specific percentage.
// It executes an AppleScript command via osascript.
func setVolume(percentage int) error {
	if percentage < 0 || percentage > 100 {
		return fmt.Errorf("percentage must be between 0 and 100")
	}

	cmd := exec.Command("osascript", "-e", fmt.Sprintf("set volume output volume %d", percentage))
	err := cmd.Run()
	if err != nil {
		return fmt.Errorf("failed to set volume: %w", err)
	}
	return nil
}

// writeConfig saves the desired volume limit to the configuration file.
func writeConfig(percentage int) error {
	return os.WriteFile(configFile, []byte(strconv.Itoa(percentage)), 0644)
}

// readConfig reads the desired volume limit from the configuration file.
func readConfig() (int, error) {
	data, err := os.ReadFile(configFile)
	if err != nil {
		return 100, err // Default to 100 if file doesn't exist
	}
	percentage, err := strconv.Atoi(string(data))
	if err != nil {
		return 100, err // Default to 100 on parsing error
	}
	return percentage, nil
}

// startDaemon starts the volume monitoring loop.
func startDaemon() {
	log.Println("Volume limiter daemon started.")
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		limit, err := readConfig()
		if err != nil {
			log.Printf("Error reading config: %v. Using default 100%%.", err)
			limit = 100
		}

		currentVolume, err := getVolume()
		if err != nil {
			log.Printf("Error getting current volume: %v", err)
			continue
		}

		if currentVolume > limit {
			log.Printf("Volume %d%% is over the limit of %d%%. Adjusting.", currentVolume, limit)
			if err := setVolume(limit); err != nil {
				log.Printf("Error setting volume: %v", err)
			}
		}
	}
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "-p", "--percentage":
			if len(os.Args) < 3 {
				fmt.Println("Please provide a percentage value")
				os.Exit(1)
			}
			percentage, err := strconv.Atoi(os.Args[2])
			if err != nil || percentage < 0 || percentage > 100 {
				fmt.Println("Invalid percentage. Please use a number between 0 and 100")
				os.Exit(1)
			}
			if err := writeConfig(percentage); err != nil {
				log.Fatalf("Failed to write config: %v", err)
			}
			fmt.Printf("Volume limit set to %d%%.\n", percentage)
			// Ensure the daemon is running by trying to apply the limit immediately
			currentVolume, err := getVolume()
			if err == nil && currentVolume > percentage {
				_ = setVolume(percentage)
			}
		case "daemon":
			startDaemon()
		default:
			fmt.Println("Usage: volume_limiter [-[ <percentage>] | [daemon]")
		}
	} else {
		startDaemon()
	}
}
