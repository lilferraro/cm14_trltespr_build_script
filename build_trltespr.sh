#!/bin/bash

# --------------------------------------
#  modify these variables to suit
#  your build environment
# --------------------------------------
GIT_USER_NAME="John Doe"
GIT_USER_EMAIL="johndoe@example.com"
CCACHE_SIZE="50G"

# --------------------------------------
#  the actual build script, do not
#  modify the lines below unless
#  you know what you are doing ;)
# --------------------------------------

function console_log {
    echo
    echo ">>> $1"
    echo
}

# perform system update
console_log "Updating Ubuntu..."
sudo apt-get update
sudo apt-get -y dist-upgrade

# install build packages
console_log "Installing build packages..."
sudo apt-get -y sudo apt-get install bison build-essential curl flex \
git gnupg gperf libesd0-dev liblz4-tool \
libncurses5-dev libsdl1.2-dev libwxgtk3.0-dev libxml2 libxml2-utils \
lzop maven openjdk-8-jdk pngcrush schedtool \
squashfs-tools xsltproc zip zlib1g-dev g++-multilib gcc-multilib \
lib32ncurses5-dev lib32readline-gplv2-dev lib32z1-dev

# create build directories
console_log "Creating build directories..."
mkdir -p ~/android/system

# download Android SDK and install Android SDK platform-tools
console_log "Downloading Android SDK..."
cd ~/android
curl http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz | tar xz

console_log "Installing platform-tools..."
cd android-sdk-linux
cat <<EOF | tools/android update sdk --no-ui --all --filter platform-tools
y
EOF

console_log "Creating udev rules for USB access..."
# enable USB access by regular user
wget -S -O - http://source.android.com/source/51-android.rules | sed "s/<username>/$USER/" | sudo tee >/dev/null /etc/udev/rules.d/51-android.rules; sudo udevadm control --reload-rules

# install repo tool
console_log "Installing repo..."
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

console_log "Setting environment variables..."

# enable ccache
cat <<EOF >> ~/.bashrc

# enable ccache for Android build
export USE_CCACHE=1
EOF

# set PATH for repo and platform-tools
cat <<EOF > ~/.profile
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "\$HOME/.bashrc" ]; then
        . "\$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/bin" ] ; then
    PATH="\$HOME/bin:\$PATH"
fi

# set PATH for Android Platform Tools
if [ -d "\$HOME/android/android-sdk-linux/platform-tools" ]; then
    PATH="\$HOME/android/android-sdk-linux/platform-tools:\$PATH"
fi
EOF

# apply changes
source ~/.profile

# set git identity
console_log "Setting user identity for Git..."
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# init repo
console_log "Initializing repo..."
cd ~/android/system
cat <<EOF | repo init -u https://github.com/CyanogenMod/android.git -b cm-14.1
N
EOF

# create local manifest
console_log "Creating local manifest for hammerheadcaf..."
mkdir -p ~/android/system/.repo/local_manifests
cat <<EOF > ~/android/system/.repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote fetch="git://github.com" name="github" />
  <remote fetch="https://github.com/" name="emotion" revision="refs/heads/nougat" />
  <remote fetch="https://github.com/" name="lilferraro" />
  <project name="EmotionOS/android_hardware_qcom_keymaster" path="hardware/qcom/keymaster" remote="emotion" revision="nougat" />
  <project name="EmotionOS/android_device_samsung_trltespr" path="device/samsung/trltespr" remote="emotion" revision="nougat" />
  <project branch="nougat" name="EmotionOS/proprietary_vendor_samsung" path="vendor/samsung" remote="emotion" />
  <project branch="cm-14.1" name="LineageOS/android_hardware_samsung" path="hardware/samsung" remote="cm" />
  <project branch="cm-14.1" name="LineageOS/android_device_samsung_qcom-common" path="device/samsung/qcom-common" remote="cm" />
  <project branch="cm-14.1" name="LineageOS/android_external_stlport" path="external/stlport" remote="cm" />
  <project name="LineageOS/android_vendor_nxp-nfc_opensource_frameworks" path="vendor/nxp-nfc/opensource/frameworks" remote="cm" revision="cm-14.1" />
  <project name="LineageOS/android_vendor_nxp-nfc_opensource_libnfc-nci" path="vendor/nxp-nfc/opensource/libnfc-nci" remote="cm" revision="cm-14.1" />
  <project name="LineageOS/android_vendor_nxp-nfc_opensource_Nfc" path="vendor/nxp-nfc/opensource/Nfc" remote="cm" revision="cm-14.1" />
  <project name="EmotionOS/proprietary_vendor_qcom_binaries" path="vendor/qcom/binaries" remote="emotion" revision="nougat" />
  <project name="EmotionOS/android_device_qcom_common" path="device/qcom/common" remote="emotion" revision="nougat" />
  <project name="EmotionOS/android_device_samsung_trlte-common" path="device/samsung/trlte-common" remote="emotion" revision="nougat" />
  <project name="lilferraro/android_kernel_samsung_trlte-1" path="kernel/samsung/trlte" remote="lilferraro" revision="cm-14.1" />
</manifest>
EOF

# sync sources
console_log "Syncing sources..."
repo sync

# set ccache size
console_log "Setting ccache size..."
prebuilts/misc/linux-x86/ccache/ccache -M $CCACHE_SIZE

# setup build environment
console_log "Preparing build environment..."
source build/envsetup.sh

# build the ROM!
console_log "Building CM 14.1 for trltespr..."
brunch trltespr
