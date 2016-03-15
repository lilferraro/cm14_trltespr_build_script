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
sudo apt-get -y install bc bison build-essential ccache curl flex gcc-multilib git-core gnupg gperf g++-multilib libc6-dev-i386 libesd0-dev libgl1-mesa-dev liblz4-tool libncurses5-dev libsdl1.2-dev libwxgtk2.8-dev libxml2 libxml2-utils libx11-dev lib32z-dev lib32ncurses5-dev lzop maven openjdk-7-jdk openjdk-7-jre pngcrush schedtool squashfs-tools unzip xsltproc x11proto-core-dev zip zlib1g-dev

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
cat <<EOF | repo init -u https://github.com/CyanogenMod/android.git -b cm-13.0
N
EOF

# create local manifest
console_log "Creating local manifest for hammerheadcaf..."
mkdir -p ~/android/system/.repo/local_manifests
cat <<EOF > ~/android/system/.repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="CyanogenMod/android_device_lge_hammerheadcaf" path="device/lge/hammerheadcaf" remote="github" />
  <project name="myfluxi/android_kernel_lge_hammerhead" path="kernel/lge/hammerhead" remote="github" revision="cm-13.0-caf-160310" />
  <project name="CyanogenMod/android_device_qcom_common" path="device/qcom/common" remote="github" />
  <project name="myfluxi/proprietary_vendor_lge" path="vendor/lge" remote="github" revision="cm-13.0" />
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
console_log "Building CM 13.0 for hammerheadcaf..."
brunch hammerheadcaf
