#!/bin/bash

set -e

export LC_ALL=C

# Initialize local repository
function init_local_repo() {
    echo -e "\033[01;33m\nCopy local manifest.xml... \033[0m"
    mkdir -p .repo/local_manifests
    cp "$(dirname "$0")/local_manifest.xml" .repo/local_manifests/manifest.xml
}

# Initialize pe repository
function init_main_repo() {
    echo -e "\033[01;33m\nInit main repo... \033[0m"
    repo init -u https://github.com/PixelExperience/manifest -b ten-plus --depth=1
}

function sync_repo() {
    echo -e "\033[01;33m\nSync fetch repo... \033[0m"
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
}

function clone_or_checkout() {
    local dir="$1"
    local repo="$2"
    local branch="$3"

    if [[ -d "$dir" ]];then
        git -C "$dir" fetch https://github.com/raysenlau/"$repo" && git -C "$dir" checkout FETCH_HEAD
    else
        git clone https://github.com/raysenlau/"$repo" "$dir"
    fi
}

function sync_origin() {
    echo -e "\033[01;33m\nSync origin device tree... \033[0m"
    clone_or_checkout device/xiaomi/davinci android_device_xiaomi_davinci
    clone_or_checkout device/xiaomi/sm6150-common android_device_xiaomi_sm6150-common
}

function apply_patches() {
    echo -e "\033[01;33m\nApplying patches... \033[0m"
    bash "$(dirname "$0")/apply-patches.sh" patches
}

function envsetup() {
    . build/envsetup.sh
    lunch aosp_davinci-userdebug
    mka installclean
}

function buildsigned() {
    DATE_START=$(date +"%s")

    # Remove old changelog file
    rm -rf $OUT/PixelExperience_*

    mka target-files-package otatools -j$(nproc --all)

    echo -e "\033[01;33m\nSigning FULL package... \033[0m"
    ./build/tools/releasetools/sign_target_files_apks -o -d ~/.android-certs \
        $OUT/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip \
        signed-target_files.zip

    echo -e "\033[01;33m\nSigning OTA package... \033[0m"
    ./build/tools/releasetools/ota_from_target_files -k ~/.android-certs/releasekey \
        signed-target_files.zip \
        signed-ota_update.zip

    # Release new full ota build
    mkdir -p release
    LIST=$(ls -1 $OUT | grep PixelExperience_)
    NAME=${LIST%%-Changelog*}

    mv signed-ota_update.zip ./release/$NAME.zip
    cd ./release && md5sum "$NAME.zip" | sed -e "s|$(pwd)||" > "$NAME.zip.md5sum" && cd ..

    mv Changelog.txt ./release/$NAME.Changelog.txt

    DATE_END=$(date +"%s")
    DIFF=$(($DATE_END - $DATE_START))
    echo -e "\033[01;32m#### Build Completed Successfully ($(($DIFF / 3600)):$(($(($DIFF % 3600)) / 60)):$(($DIFF % 60)) (hh:mm:ss)) #### \033[0m"
}

function buildbacon() {
    mka bacon -j$(nproc --all)
}

## handle command line arguments
read -p "Do you want to sync repo? (y/N) " choice_sync

if [[ $choice_sync == *"y"* ]]; then
    init_local_repo
    init_main_repo
    sync_repo
    sync_origin
    apply_patches
fi

echo -e "\033[01;33m\n###### Setting up build environment ###### \033[0m"
envsetup

read -p "Do you want a signed build? (y/N) " choice_build

if [[ $choice_build == *"y"* ]]; then
    echo -e "\033[01;33m\n###### Start building with signature ###### \033[0m"
    buildsigned
else
    echo -e "\033[01;33m\n###### Start building with bacon ###### \033[0m"
    buildbacon
fi

echo -e "\033[01;33m\n>>> Enjoy <<< \033[0m"
