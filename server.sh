#!/bin/bash

# Recommended For Ubuntu 18.04 or Higher
export LC_ALL=C

echo -e "\e[36m\e[1m---------------------------PixelOS Script By Twel12---------------------------"

# Some Useful Stuff
ota=$(date +"%s")
update_date=$(date +'%d %B %Y')
LOCAL_PATH="$(pwd)"

# Telegram
telegram () {
  ~/telegram.sh/telegram "$1" "$2" "$3" "$4" "$5"
}

# Function to Check Error Kanged From Daniel
function build_error() {
exit_code=$?
buildend=$(date +"%s")
buildtime=$(($buildend - $buildstart))
timefinal=$(timechange "$buildtime")
if [[ $exit_code != 0 ]]; then
	if [[ $1 != "" ]]; then
		echo "$1"
		echo "Exiting with status $exit_code"
		telegram -c @CatPower12 "Build Failed at $timefinal"
	else
		echo "An error was detected, exiting"
		telegram -c @CatPower12 "An Error Was Detected Build Failed at $timefinal"
	fi
	exit $exit_code
fi
}

function script_error() {
exit_code=$?
if [[ $exit_code != 0 ]]; then
	if [[ $1 != "" ]]; then
		echo "Exiting with status $exit_code"
	else
		echo "An error was detected, exiting"
	fi
	exit $exit_code
fi
}

#Time
function timechange() {
 hr=$(bc <<< "${1}/3600")
 min=$(bc <<< "(${1}%3600)/60")
 sec=$(bc <<< "${1}%60")
 printf "%02dHours, %02dMintues, %02dSeconds\n" $hr $min $sec
}

# Place Local Manifest in Place
function init_local_repo() {
    echo -e "\033[01;33m\nCopy local manifest.xml... \033[0m"
    mkdir -p .repo/local_manifests
    cp "$(dirname "$0")/$manifest" .repo/local_manifests/manifest.xml
}

# Initialize Pixel Experience repository
function init_main_repo() {
    echo -e "\033[01;33m\nInit main repo... \033[0m"
    repo init -u https://github.com/PixelExperience/manifest -b "$variant" --depth=1
}

# Start Sycing Repo
function sync_repo() {
    echo -e "\033[01;33m\nSync fetch repo... \033[0m"
    repo sync -c -q --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all) #SAVETIME
}

# Apply Patches
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

# Setup Build Enviornment
function envsetup() {
    echo -e "\033[01;33m\nEnter Build Type
1.user
2.userdebug
3.eng \033[0m"
    read -p "" choice_buildtype
    if [[ $choice_buildtype == *"1"* ]]; then
        buildtype=user
    elif [[ $choice_buildtype == *"1"* ]]; then
        buildtype=userdebug
    elif [[ $choice_buildtype == *"1"* ]]; then
        buildtype=eng
    else
        echo "Invalid Option"
        envsetup
    fi
    echo -e "\033[01;33m\n---------------- Setting up build environment ---------------- \033[0m"
    ccache -M 70G
    export USE_CCACHE=1
    export CCACHE_EXEC=$(command -v ccache)
    . build/envsetup.sh
    lunch aosp_davinci-$buildtype
    make installclean
}

# SourceForge Upload
function sourceforgeIncremental() {
    ROM=./release/$DELTA_ZIP
    ROM2=./release/$NAME.zip
    echo -e "\033[01;33m\n-------------- Uploading Build to SourceForge -------------- \033[0m"
    rsync -Ph $ROM twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/PixelOS_Davinci_Incremental/
    rsync -Ph $ROM2 twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/"$uploadfolder"/
    echo -e "\033[01;31m\n-------------------- Upload Completed --------------------\033[0m"
}

function sourceforgeFull() {
    echo -e "\033[01;33m\n-------------- Uploading Build to SourceForge -------------- \033[0m"
    rsync -Ph $Package twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/"$uploadfolder"/
    echo -e "\033[01;31m\n-------------------- Upload Completed --------------------\033[0m"
}

# Make Post
function POSTIncremental() {
update_date=$(date +'%d %B %Y')
bash ~/telegram.sh/telegram -i ~/telegram.sh/hello.jpg -c @fake_twel12 -M " #PixelOS #Android10 #Davinci #OTAUpdates

*PixelOS | Android 10*
UPDATE DATE - $update_date

> Variant - $type
> [Download (Full Package)]("$DownloadFull")
> [Download (Incremental)]("$DownloadDelta")
> [Changelog](https://raw.githubusercontent.com/Twel12/OTA/"$OTAbranch"/davinci_changelogs.txt)
> [Join Chat](t.me/CatPower12)

*Built By* [Twel12]("t.me/real_twel12")
*Follow* @RedmiK20Updates
*Join* @RedmiK20GlobalOfficial"
telegram -c @CatPower12 "Builds take 15-20 mins To Appear As Sourceforge is slow, Please be patient."
echo -e "\033[01;31m\n--------------------- Post Created ^_^ ---------------------\033[0m"
}

function POSTFull() {
bash ~/telegram.sh/telegram -i ~/telegram.sh/hello.jpg -c @fake_twel12 -M "#PixelOS #Android10 #Davinci #OTAUpdates

*PixelOS | Android 10*
UPDATE DATE - $update_date

> variant - $type
> [Download (Full Package)]("$DownloadFull")
> [Changelog](https://raw.githubusercontent.com/Twel12/OTA/$OTAbranch/davinci_changelogs.txt)
> [Join Chat](t.me/CatPower12)

*Built By* [Twel12]("t.me/real_twel12")
*Follow* @RedmiK20Updates
*Join* @RedmiK20GlobalOfficial"
telegram "Builds take 15-20 mins To Appear As Sourceforge is slow, Please be patient."
echo -e "\033[01;31m\n--------------------- Post Created ^_^ ---------------------\033[0m"
}

# Upload Test Build
function PostTEST() {
    rsync -Ph out/target/product/davinci/PixelOS*zip twel12@frs.sourceforge.net:/home/frs/project/pixelosdavinci/TestBuilds/
bash ~/telegram.sh/telegram -c @CatPower12 -M "#PixelOS #Android10 #Davinci #TestBuild
*PixelOS | Android 10*
UPDATE DATE - $update_date

*This is a Test Build*
> variant - $type
> [Download (Sourceforge)]("https://sourceforge.net/projects/pixelosdavinci/files/TestBuilds/$(basename $(ls out/target/product/davinci/PixelOS*.zip))")

*Built By* [Twel12]("t.me/real_twel12")
*Join* @CatPower12 "
}

# OTA Incremental
function OTAIncremental() {
    echo -e "\033[01;33m\n---------------------------Automatic OTA Update ---------------------------\033[0m"
PTH=./release/"$NAME".zip
FILESIZE=$(ls -al $PTH | awk '{print $5}')
md5=`md5sum $PTH | awk '{ print $1 }'`
echo -e "{
\"error\":false,
\"filename\": $NAME.zip,
\"datetime\": $ota,
\"size\":$FILESIZE,
\"url\":\"$DownloadFull\",
\"filehash\":\"$md5\",
\"version\": \"$version\",
\"id\": \"$md5\",
\"donate_url\":\"\",
\"website_url\":\"$website\",
\"news_url\":\"https:\/\/t.me\/CatPower12\",
\"maintainer\":\"Twel12\",
\"maintainer_url\":\"https:\/\/t.me/real_twel12\",
\"forum_url\":\"\"
} " > /home/twel12/"$otapath"/davinci.json
cd /home/twel12/"$otapath"
git add .
git commit -m "Automatic OTA update"
git push git@github.com:Twel12/OTA.git HEAD:$OTAbranch
cd $LOCAL_PATH
echo -e "\033[01;33m\n---------------------------Automatic OTA Update Done---------------------------\033[0m"
}

# OTA Full Zip
function OTAFULL() {
    echo -e "\e[36m\e[1m---------------------------Automatic OTA FULL PACKAGE UPDATE---------------------------"
    ZIP_PATH=$(find ./release/ -maxdepth 1 -type f -name "PixelOS*.zip" | sed -n -e "1{p;q}")
    NAME=$(basename $ZIP_PATH)
    DownloadLINK=https://sourceforge.net/projects/pixelosdavinci/files/"$uploadfolder"/"$NAME"/download
    FILESIZE=$(ls -al $ZIP_PATH | awk '{print $5}')
md5=`md5sum $ZIP_PATH | awk '{ print $1 }'`
echo -e "{
\"error\":false,
\"filename\": $NAME,
\"datetime\": $ota,
\"size\":$FILESIZE,
\"url\":\"$DownloadLINK\",
\"filehash\":\"$md5\",
\"version\": \"$version\",
\"id\": \"$md5\",
\"donate_url\": \"\",
\"website_url\":\"$website\",
\"news_url\":\"https:\/\/t.me\/CatPower12\",
\"maintainer\":\"Twel12\",
\"maintainer_url\":\"https:\/\/t.me/real_twel12\",
\"forum_url\":\"\"
} " > /home/twel12/"$otapath"/davinci.json
cd /home/twel12/"$otapath"
git add .
git commit -m "Automatic OTA update"
git push git@github.com:Twel12/OTA.git HEAD:"$OTAbranch"
cd $LOCAL_PATH
echo -e "\e[36m\e[1m---------------------------Automatic OTA Update Done---------------------------"
}

function buildsigned() {
echo -e "\033[01;33m\nChoose Desired Option 
> 1.Make Incremental with Full Package
> 2.Make Only Full Package
Enter Number: \033[0m"
read -p "" choice_signed

    # Remove old changelog file
    rm -rf $OUT/PixelOS_*
    folder=$(date +'%d %b %Y')
    if stat --printf='' ./release 2>/dev/null; then
        mv release "release $folder"
        echo "release Folder Has been renamed to \"release $folder\""
    fi
    buildstart=$(date +"%s")
    mka target-files-package otatools -j$(nproc --all)
    echo -e "\033[01;33m\nSigning FULL package... \033[0m"

    ./build/tools/releasetools/sign_target_files_apks -o -d ~/.android-certs \
        $OUT/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip \
        signed-target_files.zip
    build_error

    echo -e "\033[01;33m\nSigning OTA package... \033[0m"
    ./build/tools/releasetools/ota_from_target_files -k ~/.android-certs/releasekey \
        signed-target_files.zip \
        signed-ota_update.zip
    build_error

    # Release new full ota build
    mkdir -p release
    LIST=$(ls -1 $OUT | grep PixelOS_)
    NAME=${LIST%%-Changelog*}

    mv signed-ota_update.zip ./release/$NAME.zip
    cd ./release && md5sum "$NAME.zip" | sed -e "s|$(pwd)||" > "$NAME.zip.md5sum" && cd ..
    mv Changelog.txt ./release/$NAME.Changelog.txt

    #time
    buildend=$(date +"%s")
    buildtime=$(($buildend - $buildstart))
    timefinal=$(timechange "$buildtime")
    echo Time Taken For Build: "$timefinal"

    if [[ $choice_signed == *"1"* ]]; then
        time_incremental=$(date +"%s")
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
        FILE_SIZE_DELTA=$(ls -al ./release/"$DELTA_ZIP" | awk '{print $5}')
        FILE_SIZE_FULL=$(ls -al ./release/"$NAME".zip | awk '{print $5}')

        mv $OLDTARGET removed-$OLDLIST
        mv signed-target_files.zip signed-target_files-${NAME}.zip

        echo -e "\033[01;33m\nNew signed-target_files.zip has been renamed to signed-target_files-${NAME}.zip \033[0m"
        echo -e "\033[01;33mOld signed-target_files.zip has been renamed to removed-$OLDLIST \033[0m"

        # time
        time_incend=$(date +"%s")
        diff2=$(($time_incend - $time_incremental))
        timeinc=$(timechange "$diff2")
        echo "Time Taken For Incremental Package: $timeinc "

        telegram -c @CatPower12 "Bacon Successfull ,Time Taken For Build: $timefinal "
        DownloadFull=https://sourceforge.net/projects/pixelosdavinci/files/"$uploadfolder"/"$NAME".zip/download
        DownloadDelta=https://sourceforge.net/projects/pixelosdavinci/files/PixelOS_Davinci_Incremental/"$DELTA_ZIP"/download
        sourceforgeIncremental
        POSTIncremental
        OTAIncremental

    elif [[ $choice_signed == *"2"* ]]; then
        telegram -c @CatPower12 "Build Completed Successfully in $timefinal "
        Package=./release/PixelOS*.zip
        FULLNAME=$(basename $(ls release/PixelOS*.zip))
        sourceforgeFull
        DownloadFull=https://sourceforge.net/projects/pixelosdavinci/files/"$uploadfolder"/"$FULLNAME"/download
        POSTFull
        OTAFULL

    fi
}

function buildbacon() {
    mka bacon -j$(nproc --all)
    build_error
}

# Clean Repo
function clean_repo() {
    rm -rf .repo/manifests && echo ".repo/manifests/ --- deleted"
    rm -rf .repo/manifests.git && echo ".repo/manifests.git --- deleted"
    rm -rf .repo/repo && echo ".repo/repo/ --- deleted"
    rm -rf .repo/manifest.xml && echo ".repo/manifest.xml --- deleted"
    rm -rf .repo/project.list && echo ".repo/project.list --- deleted"
    rm -rf .repo/.repo_fetchtimes.json && echo ".repo/.repo_fetchtimes.json --- deleted"
    rm -rf patches && echo "patches --deleted"
    echo -e "\033[01;33m\n Clean Successed !!! \033[0m"
    echo -e "\033[01;32m\n Now you can sync new repo ... \033[0m"
}

# Build Options
function build() {
    read -p "Do you want a Public Release Signed build? (y/N)  " choice_build 
    if [[ $choice_build == *"y"* ]]; then
        echo -e "\033[01;33m\n------------------------ Starting Release Build (～￣▽￣)～------------------------ \033[0m"
        telegram -c @CatPower12 "Release Build Compilation Started for PixelOS

*Varient*: $type
*Android Version*: 10
*Starting Time*: $(date)"
        buildsigned
    else
        echo -e "\033[01;33m\n---------------------------Starting Test Build (*^_^*)--------------------------- \033[0m"
        read -p "Do you want to Upload our Build (y/n)" choice_test
        telegram -c @CatPower12 -M "Test Build Compilation Started for PixelOS

*Varient*: $type
*Android Version*: 10
*Starting Time*: $(date)"
        buildstart=$(date +"%s")
        buildbacon
        build_error henlo
        buildend=$(date +"%s")
        buildtime=$(($buildend - $buildstart))
        timefinal=$(timechange "$buildtime")
        if [[ $choice_test == *"y"* ]]; then
            telegram -c @CatPower12 -M "Beta Build Successfully Completed for PixelOS

*Varient*: $type
*Android Version*: 10
*Time Taken For Build*: $timefinal "
            PostTEST
        else
            telegram -c @CatPower12 -M "Test Build Successfully Completed for PixelOS

*Varient*: $type
*Android Version*: 10
*Time Taken For Build*: $timefinal "
        fi
    fi
}

# Start The Script (USING HELLO WORLD CAUSE WHY NOT ITS THE FIRST STEP TO CODING)
function helloworld() {
echo -e "\033[01;33m\nEnter the number from below for desired option.
> 1.Repo Sync
> 2.Start Bacon
> 3.Clean Repo
> 4.Exit Script

Enter Number: \033[0m"
read -p "" choice_script

    if [[ $choice_script == *"1"* ]]; then
        init_local_repo
        init_main_repo
        sync_repo
        script_error
        apply_patches patches
        envsetup
        read -p "Do You want to Start Bacon ??(y/n)" choice_bacon
        if [[ $choice_bacon == *"y"* ]]; then
            build
        else
            helloworld
        fi    
    elif [[ $choice_script == *"2"* ]]; then
        envsetup
        build
    elif [[ $choice_script == *"3"* ]]; then
        clean_repo
    elif [[ $choice_script == *"4"* ]]; then
        read -p "Are you sure you wanna Exit/End Script ? (yes/no)" choice_exit
        if [[ $choice_exit == *"yes"* ]]; then  
            echo -e "\033[01;33m\n------------------------------------K Byeee------------------------------------ \033[0m"
            exit
        else
            helloworld
        fi
    else
        echo -e "\033[01;33m\n---------------------------Invalid Option Entered--------------------------- \033[0m"
        helloworld
    fi
}

# Select Info According Build variant
echo -e "\033[01;33m\nEnter Build variant
1.Standard
2.Plus \033[0m"
read -p "" BUILD_TYPE
if [[ $BUILD_TYPE == *"1"* ]]; then
    # Variables for Build
    variant="ten"
    manifest="local_manifest.xml"
    type="Standard"
    otatpye="ten"
    otapath="OTA"
    OTAbranch="master"
    version="ten"
    website="https://sourceforge.net/projects/pixelosdavinci/files/PixelOS_Davinci/"
    uploadfolder="PixelOS_Davinci"
elif [[ $BUILD_TYPE == *"2"* ]]; then
    # Variables for Build
    variant="ten-plus"
    manifest="local_manifestplus.xml"
    type="Plus"
    otatpye="ten_plus"
    otapath="OTAPLUS"
    OTAbranch="ten"
    version="ten_plus"
    website="https://sourceforge.net/projects/pixelosdavinci/files/PixelOS_Plus_Davinci/"
    uploadfolder="PixelOS_Plus_Davinci"
else
    echo -e "\033[01;33m\nInvalid Choice \033[0m"
    exit
fi
helloworld
echo -e "\e[36m\e[1m---------------------------See Ya Later:P---------------------------"