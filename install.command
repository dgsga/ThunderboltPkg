#!/bin/zsh

#Script for compiling TbtForcePower

# Go to the root directory
cd "$(dirname $0)"

# Global variables
declare -r OPENCOREROOT="$PWD"
declare -r THREADNUMBER=$(sysctl -n hw.ncpu)

# Default values
export TOOLCHAIN=XCODE5
export WORKSPACE=${WORKSPACE:-}
export NASM_PREFIX="/usr/local/bin/"
export GCC5_BIN="/usr/local/bin/x86_64-opencore-linux-gnu-"
export BUILDTARGET=DEBUG


# Default locale
export LC_ALL=POSIX

# zsh options
set -e # errexit

## FUNCTIONS ##

#Update git repositories
git_pull() {
  for folder in $@; do
    cd "$folder"
    git pull --recurse-submodules
    cd "$EDK2DIR"
  done
}

# Copy compiled binaries
copyBin() {
  local cpSrc="$1"
  local cpDest="$2"
  local cpFile=$(basename "$2")
  local cpDestDIR=$(dirname "$cpDest")
  [[ ! -f  "$cpSrc" || ! -d  "$cpDestDIR" ]] && return
  [[ -d  "$cpDest" ]] && cpFile=$(basename "$cpSrc")
  echo "  -> $cpFile"
  cp -f "$cpSrc" "$cpDest" 2>/dev/null
}

## MAIN BUILD SCRIPT ##

MainBuildScript() {

  # Reset EDK2 environment & workspace
  echo -e "\e[1;91m Updating Git repositories and EDK2 environment... \e[0m"
  local EDK2DIR=$(cd "$OPENCOREROOT"/.. && echo "$PWD")
  cd "$EDK2DIR"
  git_pull ThunderboltPkg ./
  export EDK_TOOLS_PATH="${PWD}"/BaseTools
  export PACKAGES_PATH=$PWD/../edk2-platforms/Platform/Intel:$PWD/../edk2-platforms/Silicon/Intel
  source edksetup.sh
  echo -e "\e[1;91m Done! \e[0m"

  # Rebuild BaseTools
  echo -e "\e[1;91m Rebuilding BaseTools... \e[0m"
  make -C "$WORKSPACE"/BaseTools clean
  make -C "$WORKSPACE"/BaseTools -j $THREADNUMBER -s
  cd "$OPENCOREROOT"
  echo -e "\e[1;91m Done! \e[0m"

  # Cleanup previous build
  (
    echo -e "\e[1;91m Cleanup file tree... \e[0m"
    echo

    for dir in "$EDK2DIR"/Build; do
      find  "$dir" -mindepth 1 -not -path "**/.svn*" -delete
    done
  )
  
  echo -e "\e[1;91m Done! \e[0m"
  echo -e "\e[1;91m Building all binaries... \e[0m"
  build -a X64 -b $BUILDTARGET -t $TOOLCHAIN -n $THREADNUMBER -p ThunderboltPkg/ThunderboltPkg.dsc
  echo -e "\e[1;91m Done! \e[0m"
}

# Install TbtForcePower
MainPostBuildScript() {
  export TFP_BUILD_DIR="${WORKSPACE}/Build/ThunderboltPkg/${BUILDTARGET}_${TOOLCHAIN}/X64"
  echo -e "\e[1;91m Installing TbtForcePower... \e[0m"
  copyBin "$TFP_BUILD_DIR"/TbtForcePower.efi      /Volumes/EFI/EFI/OC/Drivers/
  echo -e "\e[1;91m Done! \e[0m"
  echo -e "\e[1;91m Installation complete. \e[0m"
}

MainBuildScript $@
MainPostBuildScript
