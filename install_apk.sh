#!/bin/bash

APP_DIR="~/Documents/Informatique/app/Logiciel/Front-End/app"
ADB="/usr/lib/android-sdk/platform-tools/adb"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"

echo "Build de l'APK..."
cd $(eval echo $APP_DIR)
flutter build apk --release

echo "Désinstallation de l'ancienne version..."
$ADB uninstall com.kornog.app

echo "Installation de la nouvelle version..."
$ADB install $(eval echo $APK_PATH)

echo "Fait!"
