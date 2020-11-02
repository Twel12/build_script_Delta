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
    repo init -u https://github.com/PixelExperience/manifest -b ten --depth=1
}

function sync_repo() {
    echo -e "\033[01;33m\nSync fetch repo... \033[0m"
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
}

function apply_patches() {
    echo -e "\033[01;33m\nApplying patches... \033[0m"
    bash "$(dirname "$0")/apply-patches.sh" patches
}

function envsetup() {
    . build/envsetup.sh
    lunch aosp_davinci-user
    mka installclean
}

function buildsigned() {    

    # Remove old changelog file
    rm -rf $OUT/PixelOS_*

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
    LIST=$(ls -1 $OUT | grep PixelOS_)
    NAME=${LIST%%-Changelog*}

    mv signed-ota_update.zip ./release/$NAME.zip
    cd ./release && md5sum "$NAME.zip" | sed -e "s|$(pwd)||" > "$NAME.zip.md5sum" && cd ..

    mv Changelog.txt ./release/$NAME.Changelog.txt

    read -p "Do you want to make Incremental build? (y/n) " choice_delta

    if [[ $choice_delta == *"y"* ]]; then

        # New build files info
        LIST=$(ls -1 out/target/product/davinci | grep PixelOS_)
        NAME=${LIST%%-Changelog*}
        TEMP=${LIST%%-UNOFFICIAL*}
        NEWDATE=${TEMP##*10.0-}

        echo -e "\033[33m\nNew build filename: ${NAME}.zip \033[0m"

        # Old build files info
        OLDLIST=$(ls -1 | grep signed-target_files-)
        OLDTARGET=${OLDLIST##*signed-target_files-}
        OLDBUILD=${OLDTARGET%%-UNOFFICIAL*}
        DELTA_ZIP="$NAME-incremental-$OLDTARGET"

        echo -e "\033[33mOld build filename: ${OLDTARGET}\033[0m"

        echo -e "\033[01;33m\nMake Incremental package... \033[0m"
        mv $OLDLIST $OLDTARGET
        ./build/tools/releasetools/ota_from_target_files --file -i \
            $OLDTARGET \
            signed-target_files.zip \
            update.zip

        mkdir -p release
        mv update.zip ./release/$DELTA_ZIP
        cd ./release && md5sum "$DELTA_ZIP" | sed -e "s|$(pwd)||" > "$DELTA_ZIP.md5sum" && cd ..

        mv $OLDTARGET removed-$OLDLIST
        mv signed-target_files.zip signed-target_files-${NAME}.zip

        echo -e "\033[01;33m\nNew signed-target_files.zip has been renamed to signed-target_files-${NAME}.zip \033[0m"
        echo -e "\033[01;33mOld signed-target_files.zip has been renamed to removed-$OLDLIST \033[0m"

        bash ~/telegram.sh/telegram "Bacon Successfull ^_^"

        #Sourceforge Upload
        DIR=/home/frs/project/pixelosdavinci/
        ROM=release/$DELTA_ZIP
        ROM2=release/$NAME.zip
        rsync -Ph $ROM twel12@frs.sourceforge.net:"$DIR"PixelOS_Davinci_Incremental/
        rsync -Ph $ROM2 twel12@frs.sourceforge.net:"$DIR"PixelOS_Davinci/
        echo -e "\033[01;31m\nUpload Completed ^_^\033[0m"
        echo -e "\033[01;31m\nCreating Download Post ^_^\033[0m"
        POST
        echo -e "\033[01;31m\nPost Created ^_^\033[0m"
    fi
        echo -e "\033[01;31m\nIncremental build Canceled!\033[0m"

echo -e "\033[01;32m\n#### PixelOS Baked Successfully ^_^ #### \033[0m"
}

function buildbacon() {
    mka bacon -j$(nproc --all)
    bash ~/telegram.sh/telegram -c -1001391319022 "Bacon Successfull ¯\_(ツ)_/¯"
}

## handle command line arguments
read -p "Do you want to sync repo? (y/N) " choice_sync

if [[ $choice_sync == *"y"* ]]; then
    init_local_repo
    init_main_repo
    sync_repo
    apply_patches
fi

echo -e "\033[01;33m\n###### Setting up build environment ###### \033[0m"
envsetup

#Make Post
function POST() {
    DownloadFull=https://sourceforge.net/projects/pixelosdavinci/files/PixelOS_Davinci/"$NAME".zip/download
DownloadDelta=https://sourceforge.net/projects/pixelosdavinci/files/PixelOS_Incremental/"$DELTA_ZIP"/download
bash ~/telegram.sh/telegram -i ~/telegram.sh/hello.jpg -M "#PixelOS #Android10 #Davinci #OTAUpdates
*Pixel OS | Android 10*
> [Download (Full Package)]("$DownloadFull")
> [Download (Incremental)]("$DownloadDelta")
> [Changelog](https://raw.githubusercontent.com/Twel12/android_OTA/master/davinci_changelogs.txt)
> [Join Chat](t.me/CatPower12) 
Note - Incremental Pushed Via Update too :)
*Built By* @Twel12
*Follow* @RedmiK20Updates
*Join* @RedmiK20GlobalOfficial"
}

read -p "Do you want a signed build? (y/N) " choice_build 
if [[ $choice_build == *"y"* ]]; then
    echo -e "\033[01;33m\n###### Starting Release Build (～￣▽￣)～ ###### \033[0m"
    bash ~/telegram.sh/telegram "Release Build Started(～￣▽￣)～"
    buildsigned || bash ~/telegram.sh/telegram "Build Failed :("

else
    echo -e "\033[01;33m\n###### Starting Test Build (*^_^*) ###### \033[0m"
    bash ~/telegram.sh/telegram -c -1001391319022 "Test Build Started 😀"
    buildbacon || bash ~/telegram.sh/telegram -c -1001391319022 "Build Failed :("

fi