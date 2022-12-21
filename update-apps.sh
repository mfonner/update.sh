#!/bin/bash

###
### Checks for updates to applications that do not update themselves
###

# TODO: Add flag for GitHub personal token
# TODO: Add option to install updates all at once or one at a time
# TODO: Make this platform agnostic i.e. check for debian

###
### Dependency check
###


# Ensure curl is installed
if ! command -v curl &>/dev/null
then
  printf "Curl is not available. Please install curl and then try again."
  exit
fi

# Ensure jq is installed
if ! command -v jq &>/dev/null
then
  printf "jq is not available. Please install jq and try again."
  exit
fi

# Ensure wget is installed
if ! command -v wget &>/dev/null
then
  printf "wget is not available. Please install wget and try again."
  exit
fi


###
### Get installed application versions
###


printf "\nInstalled versions:\n"

# Bitwarden
bitwarden_version=$(rpm -q --qf "%{VERSION}\n" bitwarden)
printf "\nBitwarden: $bitwarden_version\n"

# WebCord
webcord_version=$(rpm -q --qf "%{VERSION}\n" webcord)
printf "WebCord: $webcord_version\n"

# Heroic
heroic_version=$(rpm -q --qf "%{VERSION}\n" heroic)
printf "Heroic: $heroic_version\n"


###
### Get latest release versions
###


# TODO: Refactor this to save the initial json response 
# This way we are more efficient with our GitHub API queries
# Define app urls and curl command for better readability

curl_cmd () {
  curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GHPT"\
    -H "X-GitHub-Api-Version: 2022-11-28" \
    $1 | jq -r  '.tag_name' | cut -d "v" -f 2-
}

bitwarden_url="https://api.github.com/repos/bitwarden/clients/releases/latest"
webcord_url="https://api.github.com/repos/SpacingBat3/WebCord/releases/latest"
heroic_url="https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest"

# Latest Bitwarden version
bitwarden_latest=$(curl_cmd $bitwarden_url)
printf "\nLatest Bitwarden version detected: $bitwarden_latest"

# Latest WebCord version
webcord_latest=$(curl_cmd $webcord_url)
printf "\nLatest WebCord version detected: $webcord_latest"

# Latest Heroic version
heroic_latest=$(curl_cmd $heroic_url)
printf "\nLatest Heroic version detected: $heroic_latest\n"


###
### Version comparision
###


# This is a bash dictionary object
# Probably over-engineered
declare -A available_updates=( [Bitwarden]="false" [Heroic]="false" [WebCord]="false" )

# These comparisons follow the assumption that the locally installed version
# cannot be greater than the version that's published on GitHub

# Bitwarden verions
if [[ "$bitwarden_version" != "$bitwarden_latest" ]]
then
    available_updates[Bitwarden]="true"
fi  

# WebCord verions
if [[ "$webcord_version" != "$webcord_latest" ]]
then
    available_updates[WebCord]="true"
fi

# Heroic verions
if [[ "$heroic_version" != "$heroic_latest" ]]
then
    available_updates[Heroic]="true"
fi

# Looping through values in our dictionary to see what updates are available
# If updates are not available, we remove that key from our dictionary
for key in "${!available_updates[@]}"; do
  if [[ ${available_updates[$key]} != "true" ]]; then
    unset available_updates[$key]
  fi
done

# Inform user of available updates
for key in "${!available_updates[@]}"; do printf "\nUpdate available for $key"; done


###
### Download and install applications
###


download_dir="$HOME/Downloads/"

get_download_url () {
  for key in "${!available_updates[@]}"; do
    if [[ "$key" == *"Bitwarden"* ]]; then
      curl -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GHPT"\
        -H "X-GitHub-Api-Version: 2022-11-28" \
        $1 | grep browser_download_url #| grep "x86_64.rpm" | cut -d '"' -f 4
    else
      curl -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GHPT"\
        -H "X-GitHub-Api-Version: 2022-11-28" \
        $1 | grep browser_download_url | grep "x86_64.rpm" | cut -d '"' -f 4
    fi
  done
}

# Saving download links for use later

# Checking that Bitwarden's update is for the Desktop version
# TODO: Could probably fix this by checking for tags
bitwarden_dl_url=$(get_download_url $bitwarden_url)

if [[ $bitwarden_dl_url == *"chrome"* ]]; then
  unset available_updates[Bitwarden]
  printf "\nBrowser update available for Bitwarden, not desktop. Skipping.\n"
fi

webcord_dl_url=$(get_download_url $webcord_url)
heroic_dl_url=$(get_download_url $heroic_url)

download_update () {
  printf "Downloading $1...\n"
  wget -q $1 -P $download_dir 
  printf "Done.\n"
}

# Download update from valid (update is available) key value
download_update_from_key () {
  if [[ "$1" == *"Bitwarden"* ]]; then
    download_update $bitwarden_dl_url
  elif [[ "$1" == *"WebCord"* ]]; then
    download_update $webcord_dl_url
  elif [[ "$1" == *"Heroic"* ]]; then
    download_update $heroic_dl_url
  fi
}

# This function also cleans up after ourselves
get_dl_and_install () {
  rpm_path=$(find $download_dir -type f -iname "*$1*")
  printf "Installing $1...\n"
  sudo dnf install $rpm_path
  printf "Done, prompting for clean up of downloaded file(s)...\n"
  rm -i $rpm_path
}

# Installation loop
for key in "${!available_updates[@]}"; do 
  read -p $'\n'"Do you want to download and install updates for $key: " yn
  case $yn in
    [Yy]* ) download_update_from_key $key; get_dl_and_install $key; exit;;
    [Nn]* ) exit;;
    * ) printf "Please specify (y)es or (n)o\n";;
  esac
done
