#!/bin/sh

if [ "$1" == "hockeyapp" ]; then
	FASTLANE_BUILD_CONFIGURATION="internalhockeyapp"
	CERTS_PATH="codesigning_data/certs"
	PROFILES_PATH="codesigning_data/profiles"
elif [ "$1" == "appstore" ]; then
	FASTLANE_BUILD_CONFIGURATION="testflight_llc"
	if [ -z "$TELEGRAM_BUILD_APPSTORE_PASSWORD" ]; then
		echo "TELEGRAM_BUILD_APPSTORE_PASSWORD is not set"
		exit 1
	fi
	if [ -z "$TELEGRAM_BUILD_APPSTORE_TEAM_NAME" ]; then
		echo "TELEGRAM_BUILD_APPSTORE_TEAM_NAME is not set"
		exit 1
	fi
	FASTLANE_PASSWORD="$TELEGRAM_BUILD_APPSTORE_PASSWORD"
	FASTLANE_ITC_TEAM_NAME="$TELEGRAM_BUILD_APPSTORE_TEAM_NAME"
	CERTS_PATH="codesigning_data/certs"
	PROFILES_PATH="codesigning_data/profiles"
elif [ "$1" == "verify" ]; then
	FASTLANE_BUILD_CONFIGURATION="build_for_appstore"
	CERTS_PATH="buildbox/fake-codesigning/certs"
	PROFILES_PATH="buildbox/fake-codesigning/profiles"
elif [ "$1" == "verify-local" ]; then
	FASTLANE_BUILD_CONFIGURATION="build_for_appstore"
	CERTS_PATH="buildbox/fake-codesigning/certs"
	PROFILES_PATH="buildbox/fake-codesigning/profiles"
else
	echo "Unknown configuration $1"
	exit 1
fi

MY_KEYCHAIN="temp.keychain"
MY_KEYCHAIN_PASSWORD="secret"

if [ ! -z "$(security list-keychains | grep "$MY_KEYCHAIN")" ]; then
	security delete-keychain "$MY_KEYCHAIN" || true
fi
security create-keychain -p "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"
security list-keychains -d user -s "$MY_KEYCHAIN" $(security list-keychains -d user | sed s/\"//g)
security set-keychain-settings "$MY_KEYCHAIN"
security unlock-keychain -p "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"

for f in $(ls "$CERTS_PATH"); do
	fastlane run import_certificate "certificate_path:$CERTS_PATH/$f" keychain_name:"$MY_KEYCHAIN" keychain_password:"$MY_KEYCHAIN_PASSWORD" log_output:true
done

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"

for f in $(ls "$PROFILES_PATH"); do
	PROFILE_PATH="$PROFILES_PATH/$f"
	uuid=`grep UUID -A1 -a "$PROFILE_PATH" | grep -io "[-A-F0-9]\{36\}"`
	cp -f "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
done

if [ "$1" == "verify-local" ]; then
	fastlane "$FASTLANE_BUILD_CONFIGURATION"
else
	SOURCE_PATH="telegram-ios"

	if [ -d "$SOURCE_PATH" ]; then
		echo "Directory $SOURCE_PATH should not exist"
		exit 1
	fi

	echo "Unpacking files..."
	tar -xf "source.tar"

	cd "$SOURCE_PATH"
	FASTLANE_PASSWORD="$FASTLANE_PASSWORD" FASTLANE_ITC_TEAM_NAME="$FASTLANE_ITC_TEAM_NAME" fastlane "$FASTLANE_BUILD_CONFIGURATION"
fi
