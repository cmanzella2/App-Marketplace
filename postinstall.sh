#!/bin/bash

currentUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
destinationPath="/Users/$currentUser/Desktop"
fullPath="/Users/$currentUser/Desktop/App Marketplace.shortcut"
shortcutPath="/tmp/App Marketplace.shortcut"

mv "$shortcutPath" "$destinationPath"
chown "$currentUser" "$fullPath"
chgrp "staff" "$fullPath"
echo "Done..."