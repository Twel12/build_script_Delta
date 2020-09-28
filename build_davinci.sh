#!/bin/bash

set -e

export LC_ALL=C

echo -e "\033[01;33m\n---------------------------PixelOS Script By Twel12--------------------------- \033[0m"
echo -e "\033[01;33m\n----------------------------------Script V1.0--------------------------------- \033[0m"

# Place Local Manifest in Place
function init_local_repo() {
    echo -e "\033[01;33m\nCopy local manifest.xml... \033[0m"
    mkdir -p .repo/local_manifests
    cp "$(dirname "$0")/local_manifest.xml" .repo/local_manifests/manifest.xml
}

# Initialize Pixel Experience repository
function init_main_repo() {
    echo -e "\033[01;33m\nInit main repo... \033[0m"
    repo init -u https://github.com/PixelExperience/manifest -b ten --depth=1
}

#Start Sycing Repo
function sync_repo() {
    echo -e "\033[01;33m\nSync fetch repo... \033[0m"
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
}

#Apply Patches
function apply_patches() {
    echo -e "\033[01;33m\nApplying patches... \033[0m"
    patches="$(readlink -f -- $1)"

    for project in $(cd $patches/patches; echo *);do
        p="$(tr _ / <<<$project)"
        [ "$p" == build ] && p=build/make
        repo sync -l --force-sync $p || continue
        pushd $p
        git clean -fdx; git reset --hard
        for patch in $patches/patches/$project/*.patch;do
            #Check if patch is already applied
            if patch -f -p1 --dry-run -R < $patch > /dev/null;then
                echo -e "\033[01;33m\n Already patched... \033[0m"
                continue
            fi

            if git apply --check $patch;then
                echo -e "\033[01;32m"
                git am $patch
                echo -e "\033[0m"
            elif patch -f -p1 --dry-run < $patch > /dev/null;then
                #This will fail
                echo -e "\033[32m"
                git am $patch || true
                patch -f -p1 < $patch
                git add -u
                git am --continue
                echo -e "\033[0m"
            else
                echo -e "\033[01;31m\n Failed applying $patch ... 033[0m"
            fi
        done
        popd
    done
}

#Setup Build Enviornment
function envsetup() {
    echo -e "\033[01;33m\n---------------- Setting up build environment ---------------- \033[0m"
    . build/envsetup.sh
    lunch aosp_davinci-user
    export USE_CCACHE=1
    mka installclean
}

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

*Built By* @Twel12
*Follow* @RedmiK20Updates
*Join* @RedmiK20GlobalOfficial"
bash ~telegram.sh /telegram "Builds take 15-20 mins To Appear As Sourceforge is slow, Please be patient."
}

#Upload Test Build
function TEST(){
    rsync -Ph out/target/product/davinci/PixelOS*zip twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/TestBuilds/
bash ~/telegram.sh/telegram -M "#PixelOS #Android10 #Davinci #TestBuild
*Pixel OS | Android 10*

*This is a Test Build*

> [Download (Sourceforge)]("https://sourceforge.net/projects/pixelosdavinci/files/TestBuilds/$(basename $(ls out/target/product/davinci/PixelOS*.zip))")
> [Join Chat](t.me/CatPower12)"
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

        #Sourceforge Upload
        ROM=release/$DELTA_ZIP
        ROM2=release/$NAME.zip
        echo -e "\033[01;33m\n-------------- Uploading Build to SourceForge -------------- \033[0m"
        rsync -Ph $ROM twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/PixelOS_Davinci_Incremental/
        rsync -Ph $ROM2 twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/PixelOS_Davinci/
        echo -e "\033[01;31m\n-------------------- Upload Completed --------------------\033[0m"
        echo -e "\033[01;31m\n---------------- Creating Download Post ^_^ ----------------\033[0m"
        POST
        echo -e "\033[01;31m\n--------------------- Post Created ^_^ ---------------------\033[0m"
    fi
        echo -e "\033[01;31m\n ---------------Incremental build Canceled! ---------------\033[0m"

echo -e "\033[01;32m\n----------------------- PixelOS Baked Successfully ^_^ ----------------------- \033[0m"
}

function buildbacon() {
    mka bacon -j$(nproc --all)
    read -p "Do you want to Upload Build (y/n)" choice_test

    if [[ $choice_test == *"y"* ]]; then
        TEST
    else
        bash ~/telegram.sh/telegram "Build Successfull ^_^"
    fi
}

#Clean Repo
function clean_repo() {
    rm -rf .repo/manifests && echo ".repo/manifests/ --- deleted"
    rm -rf .repo/manifests.git && echo ".repo/manifests.git --- deleted"
    rm -rf .repo/repo && echo ".repo/repo/ --- deleted"
    rm -rf .repo/manifest.xml && echo ".repo/manifest.xml --- deleted"
    rm -rf .repo/project.list && echo ".repo/project.list --- deleted"
    rm -rf .repo/.repo_fetchtimes.json && echo ".repo/.repo_fetchtimes.json --- deleted"
    echo -e "\033[01;33m\n Clean Successed !!! \033[0m"
    echo -e "\033[01;32m\n Now you can sync new repo ... \033[0m"
}

#Build Options
function build() {
    read -p "Do you want a signed build? (y/N) " choice_build 
    if [[ $choice_build == *"y"* ]]; then
        echo -e "\033[01;33m\n------------------------ Starting Release Build (～￣▽￣)------------------------ \033[0m"
        bash ~/telegram.sh/telegram "Release Build Started(～￣▽￣)～"
        buildsigned || bash ~/telegram.sh/telegram "Build Failed :("

    else
        echo -e "\033[01;33m\n---------------------------Starting Test Build (*^_^*)--------------------------- \033[0m"
        bash ~/telegram.sh/telegram "Test Build Started 😀"
        buildbacon || bash ~/telegram.sh/telegram "Build Failed :("

    fi
}

#Start The Script
read -p "Enter the number from below for desired option.
> 1.Repo Sync
> 2.Start Bacon
> 3.Clean Repo

Enter Number:" choice_script

if [[ $choice_script == *"1"* ]]; then
    init_local_repo
    init_main_repo
    sync_repo
    apply_patches
    envsetup

elif [[ $choice_script == *"2"* ]]; then
    envsetup
    build

elif [[ $choice_script == *"3"* ]]; then
    clean_repo

else
    echo -e "\033[01;33m\n---------------------------Invalid Option Entered--------------------------- \033[0m"
fi
