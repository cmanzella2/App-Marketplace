#!/bin/bash

# 1. app-store.png must be installed in /usr/local/App Marketplace/.
# 2. Add apps and their Installomator label in the apps array down below if you wish.

# Define current user
currentUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Define installomator path
installomatorPath="/usr/local/Installomator/Installomator.sh"

# Define installomator repo URL, download URL, and get latest version.
installomatorRepoURL="https://api.github.com/repos/Installomator/Installomator/releases/latest"
installomatorDownloadURL=$( curl -L -s "$installomatorRepoURL" | grep "browser_download_url" | grep ".pkg" | awk '{ print $2 }' | tr -d '"' )
installomatorLatestVersion=$( curl -L -s "$installomatorRepoURL" | awk -F '"' '/"tag_name"/ {print $4}' | tr -d 'v' )
installomatorPackagePath="/Users/$currentUser/Downloads/Installomator-$installomatorLatestVersion.pkg"

# Define Swift Dialog path
swiftDialogPath="/usr/local/bin/dialog"

# Define Swift Dialog repo URL, download URL, and get latest version.
swiftDialogRepoURL="https://api.github.com/repos/bartreardon/swiftDialog/releases/latest"
swiftDialogDownloadURL=$( curl -L -s "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | grep "browser_download_url" | grep ".pkg" | awk '{ print $2 }' | tr -d '"' | sed '/dialog-launcher.pkg/d' )
swiftDialogLatestVersion=$( curl -L -s "$swiftDialogRepoURL" | awk -F '"' '/"tag_name"/ {print $4}' | tr -d 'v' )
swiftDialogPackagePath="/Users/$currentUser/Downloads/Swift Dialog-$swiftDialogLatestVersion.pkg"

# Define the icon path
icon='/usr/local/App Marketplace/app-store.png'

# Define the command file for updating dialog
dialogLog="/var/tmp/dialog.log"
rm -f "$dialogLog" # Ensure a fresh log file

# Check if Installomator needs to be installed
echo "Checking if insatllomator is installed..." >> "$dialogLog"

if [ ! -f "$installomatorPath" ]; then
  echo "Installomator is not installed." >> "$dialogLog"
  echo "Installing..." >> "$dialogLog"
  curl -L -o "$installomatorPackagePath" "$installomatorDownloadURL" >> "$dialogLog"
  sudo installer -pkg "$installomatorPackagePath" -target / >> "$dialogLog"
  echo "Done..." >> "$dialogLog"
  echo "Cleaning up..." >> "$dialogLog"
  rm -rf "$installomatorPackagePath"
else
  echo "Installomator is installed." >> "$dialogLog"
  echo "Proceeding..." >> "$dialogLog"
fi

# Check if swiftdialog needs to be installed
echo "Checking if Swift Dialog is installed..." >> "$dialogLog"

if [ ! -f "$swiftDialogPath" ]; then
  echo "Swift Dialog is not installed." >> "$dialogLog"
  echo "Installing..." >> "$dialogLog"
  curl -L -o "$swiftDialogPackagePath" "$swiftDialogDownloadURL" >> "$dialogLog"
  sudo installer -pkg "$swiftDialogPackagePath" -target / >> "$dialogLog"
  echo "Done..." >> "$dialogLog"
  echo "Cleaning up..." >> "$dialogLog"
  rm -rf "$swiftDialogPackagePath"
else
  echo "Swift Dialog is installed." >> "$dialogLog"
  echo "Proceeding..." >> "$dialogLog"
fi

# Define the available apps with proper names and Installomator labels
apps=(
  "Balena Etcher:balenaetcher"
  "Discord:discord"
  "Dockutil:dockutil"
  "Google Chrome:googlechrome"
  "IntelliJ IDEA:jetbrainsintellijidea"
  "Microsoft Defender:microsoftdefender"
  "Microsoft Edge:microsoftedge"
  "Microsoft Office 365:microsoftoffice365"
  "Microsoft OneDrive:microsoftonedrive"
  "Microsoft Windows App:microsoftwindowsapp"
  "Nord VPN:nordvpn"
  "Nudge:nudge"
  "Python:python"
  "Team Viewer:teamviewer"
  "UTM:utm"
  "VLC:vlc"
  "Wireshark:wireshark"
  "Zoom:zoom"
)

# Build the checkbox list
appList=""
for app in "${apps[@]}"; do
  appName=$(echo "$app" | cut -d':' -f1)   # User-friendly name
  appLabel=$(echo "$app" | cut -d':' -f2)  # Installomator label
  appList+="--checkbox \"$appName\" \"$appName\" off "
done

# Display dialog and capture JSON output
dialogOutput=$(eval "/usr/local/bin/dialog -o -i '$icon' \
  --resizable \
  --title 'App Marketplace' \
  --message 'Select the apps to install:' \
  --button1text 'Install Selected' \
  --button2text 'Quit' \
  --json \
  $appList")

# Check if user pressed "Quit"
buttonPressed=$(echo "$dialogOutput" | jq -r '.buttonPressed')
if [[ "$buttonPressed" == "Quit" ]]; then
  echo "User quit the installer. Exiting..." >> "$dialogLog"
  exit 0
fi

# Extract selected apps from JSON
selectedLabels=()
for app in "${apps[@]}"; do
  appName=$(echo "$app" | cut -d':' -f1)
  appLabel=$(echo "$app" | cut -d':' -f2)
  if echo "$dialogOutput" | jq -r --arg app "$appName" '.[$app]' | grep -q "true"; then
    selectedLabels+=("$appLabel")
  fi
done

# Check if any apps were selected
if [[ ${#selectedLabels[@]} -eq 0 ]]; then
  echo "No apps selected. Exiting..." >> "$dialogLog"
  exit 0
fi

# Open progress bar in mini mode
dialogCMD="/usr/local/bin/dialog -i '$icon' -o --title 'App Marketplace' \
  --message 'Installing selected applications...' \
  --progress --progresstext 'Installing...' --mini --json --commandfile $dialogLog"

eval "$dialogCMD" &

# Install selected apps using Installomator with dynamic progress text
appCount=${#selectedLabels[@]}
progress=0
progressIncrement=$((100 / appCount))

for label in "${selectedLabels[@]}"; do
  progress=$((progress + progressIncrement))
  
  echo "status: Installing $label..." >> "$dialogLog"
  echo "progress: $progress" >> "$dialogLog"
  echo "progresstext: Installing $label... ($progress%)" >> "$dialogLog"

  /usr/local/Installomator/Installomator.sh "$label" LOGO="$icon"
done

# Mark as complete
echo "status: Installation complete!" >> "$dialogLog"
echo "progress: 100" >> "$dialogLog"
echo "progresstext: Installation complete!" >> "$dialogLog"

# Allow time for user to see completion
sleep 2

# Properly close the dialog
echo "quit:" >> "$dialogLog"
