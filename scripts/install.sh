#!/bin/bash

# variables
cling_binary_release_date="2018-11-01"

# color helpers
function heading () {
	printf '\e[48;1;4m%s\e[0m \n' "$1"
}

function notice () {
	printf '\e[0;32m%s\e[0m \n' "$1"
}

function error () {
	printf '\e[41m%s\e[0m \n' "$1"
	exit;
}

function warn () {
	printf '\e[48;5;208m%s\e[0m \n' "$1"
}

function color_grad () {
	if [ "$1" -lt "$2" ]; then
		for (( i=$1; i<=$2; i++ )); do printf "\e[48;5;${i}m \e[0m" ; done ;
	else
		for (( i=$1; i>=$2; i-- )); do printf "\e[48;5;${i}m \e[0m" ; done ;
	fi
}

function fancy_heading () {
	#color_grad 16 21
	printf "%-60s" "$1"
	#color_grad 21 16
	printf "\n"
}

function fancy_sep () {
	local colored_ws=$(printf "%60s" " " | sed -e 's/./\\e[48;5;21m \\e[0m/g');

	#color_grad 16 21
	#printf "$colored_ws"
	#color_grad 21 16
	printf "\n"
}

function colored_ws () {
	#local colored_ws=$(echo "$2" | sed -e 's/./\\e[48;5;'"$1"'m \\e[0m/g');
	local colored_ws=$(printf "%$2s" " " | sed -e 's/./\\e[48;5;'"$1"'m \\e[0m/g');
	#printf "$colored_ws";
}

# progress filter for wget
function progressfilt () {
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

# ----------------------------------------------------------------------------------------------------------------------
fancy_sep
fancy_heading "     ____   ______ ______ ____   __  __ _____ ______ ____   ___   ______ ____   ____  "
fancy_heading "    / __ \ / ____// ____// __ \ / / / // ___//_  __// __ \ /   | /_  __// __ \ / __ \ "
fancy_heading "   / / / // __/  / /_   / /_/ // / / / \__ \  / /  / /_/ // /| |  / /  / / / // /_/ / "
fancy_heading "  / /_/ // /___ / __/  / _, _// /_/ / ___/ / / /  / _, _// ___ | / /  / /_/ // _, _/  "
fancy_heading " /_____//_____//_/    /_/ |_| \____/ /____/ /_/  /_/ |_|/_/  |_|/_/   \____//_/ |_|   "
fancy_heading "                                                                                      "
fancy_heading " Contact"
fancy_heading "   Till Ehrengruber"
fancy_heading "   till@ehrengruber.ch"
fancy_sep

# Download repository
git clone https://github.com/tehrengruber/Defrustrator.git ~/.defrustrator

cd ~/.defrustrator

# Check prerequisites
heading "Check if all prerequisites are installed"
which git > /dev/null
if [ $? -ne 0 ]; then
  error "git is not installed"
fi

which cmake > /dev/null
if [ $? -ne 0 ]; then
  error "cmake is not installed"
fi

which wget > /dev/null
if [ $? -ne 0 ]; then
  error "wget is not installed"
fi
notice "Done."

# Download cling
heading "Download cling"
#  todo: test what happens on linux mint
if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
  lsb_release -a 2>&1 | sed -r -e 's/Description:[\t]//;t;d' | grep Ubuntu > /dev/null
  if [ $? -eq 0 ]; then
    notice "Found Ubuntu operating system"
  else
    warn "Found ubuntu like operating system"
  fi

  # determine major_release version number
  major_release=$(lsb_release -a 2>&1 | sed -r -e 's/Release:[\t]//;t;d' | sed -re 's/([0-9]+)\.[0-9]+/\1/')
  if (( $major_release % 2 != 0 )); then
      echo "You are using a non LTS release of ubuntu. This is not officially supported"
      major_release=$(($major_release-1))
  fi

  # determine url
  cling_binary_release_filename="cling_${cling_binary_release_date}_ubuntu${major_release}.tar.bz2"
  cling_binary_download_url="https://root.cern.ch/download/cling/${cling_binary_release_filename}"

  # todo: test that url is valid
elif [ -f /etc/fedora-release ]; then
  notice "Found operating system Fedora"
  release=$(cat /etc/fedora-release | sed -r 's/Fedora release ([0-9]+).*/\1/')´
  cling_binary_release_filename="cling_${cling_binary_release_date}_fedora${release}.tar.bz2"
  cling_binary_download_url="https://root.cern.ch/download/cling/${cling_binary_release_filename}"
fi

if [ -f $cling_binary_release_filename ]; then
  notice "Found existing cling package download. Skipping download."
else
  wget --directory-prefix=/tmp --progress=bar:force $cling_binary_download_url 2>&1 | progressfilt
  if [ $? -ne 0 ]; then
    error "Download failed."
  fi
fi

notice "Extracting $cling_binary_release_filename"
if [ -d bin/cling ]; then
    notice "Found existing cling package download. Skipping extraction."
else
    mkdir -p bin/cling
    tar jxf /tmp/$cling_binary_release_filename -C bin/cling --strip-components 1
fi

# Compile
heading "Compile plugin"
mkdir -p build
pushd build > /dev/null
cmake ..
make
popd > /dev/null
