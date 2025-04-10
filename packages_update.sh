#!/bin/bash
set -euo pipefail

# Function to detect the operating system
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$ID"
    VER="$VERSION_ID"
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi
}

# Function to update packages and log output
update_packages() {
  LOGFILE="$HOME/update.log"
  : > "$LOGFILE"  # Clear any existing log

  case "$OS" in
    centos)
      if [ "$VER" == "7" ]; then
        sudo yum -y update 2>&1 | tee -a "$LOGFILE"
      elif [ "$VER" == "8" ]; then
        sudo dnf -y update 2>&1 | tee -a "$LOGFILE"
      fi
      ;;
    rhel)
      if [ "$VER" == "8" ] || [ "$VER" == "9" ]; then
        sudo dnf -y update 2>&1 | tee -a "$LOGFILE"
      fi
      ;;
    ubuntu)
      sudo apt-get update 2>&1 | tee -a "$LOGFILE"
      sudo apt-get -y upgrade 2>&1 | tee -a "$LOGFILE"
      ;;
    Darwin)
      eval "$(/opt/homebrew/bin/brew shellenv)"
      brew update 2>&1 | tee -a "$LOGFILE"
      brew upgrade 2>&1 | tee -a "$LOGFILE"
      ;;
    *)
      echo "Unsupported OS: $OS $VER" | tee -a "$LOGFILE"
      exit 1
      ;;
  esac

  if grep -i "warning\|error" "$LOGFILE"; then
    echo "Warnings or errors found during update. Check $LOGFILE for details."
  else
    echo "Update completed successfully with no warnings or errors."
    rm "$LOGFILE"
  fi
}

# Function to perform package cleanup
clean_up() {
  LOGFILE="$HOME/update.log"
  echo "Performing cleanup..." | tee -a "$LOGFILE"
  case "$OS" in
    centos)
      if [ "$VER" == "7" ]; then
        sudo yum -y clean all 2>&1 | tee -a "$LOGFILE"
      elif [ "$VER" == "8" ]; then
        sudo dnf -y clean all 2>&1 | tee -a "$LOGFILE"
      fi
      ;;
    rhel)
      if [ "$VER" == "8" ] || [ "$VER" == "9" ]; then
        sudo dnf -y clean all 2>&1 | tee -a "$LOGFILE"
      fi
      ;;
    ubuntu)
      sudo apt-get -y autoremove 2>&1 | tee -a "$LOGFILE"
      sudo apt-get clean 2>&1 | tee -a "$LOGFILE"
      ;;
    Darwin)
      brew cleanup 2>&1 | tee -a "$LOGFILE"
      ;;
    *)
      echo "No cleanup commands defined for OS: $OS" | tee -a "$LOGFILE"
      ;;
  esac
}

# Parameter parsing:
# If "--clean" is passed as the first argument or if the environment variable CLEAN is "true",
# then set DO_CLEAN to true.
DO_CLEAN=false
if [ "${1:-}" == "--clean" ]; then
  DO_CLEAN=true
fi
if [ "${CLEAN:-false}" = "true" ]; then
  DO_CLEAN=true
fi

# Main script execution
detect_os
update_packages

# If cleanup is requested, run the clean_up function.
if [ "$DO_CLEAN" = true ]; then
  clean_up
fi