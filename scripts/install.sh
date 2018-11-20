#!/bin/bash

# variables
CLING_BINARY_RELEASE_DATE="2018-11-01"
UPDATE=true

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

#
# Check prerequisites
#
heading "Check if all prerequisites are installed"
which git &> /dev/null
if [ $? -ne 0 ]; then
  error "git is not installed"
fi

which cmake &> /dev/null
if [ $? -ne 0 ]; then
  error "cmake is not installed"
fi

which wget &> /dev/null
if [ $? -ne 0 ]; then
  error "wget is not installed"
fi

which make &> /dev/null
if [ $? -ne 0 ]; then
  error "make is not installed"
fi

which tar &> /dev/null
if [ $? -ne 0 ]; then
  error "tar is not installed"
fi

notice "Done."

#
# Download repository
#
heading "Repository Setup"
BASE_PATH="~/.defrustrator"
if [ -d "$(pwd)/.git" ]; then
    # todo: check if it is not another repository (i.e. by the id of the first commit)
    pushd "$(pwd)" > /dev/null
    notice "Using BASE_PATH $(pwd)"
    BASE_PATH="$(pwd)"
    popd > /dev/null
fi
if [ ! -d "$BASE_PATH" ]; then
    git clone https://github.com/tehrengruber/Defrustrator.git $BASE_PATH
elif $UPDATE ; then
    notice "Update? [yes, no]:"
    read PROCEED
    if [ "$PROCEED" = "yes" ]; then
        notice "Directory $BASE_PATH already exists. Updating."
        pushd $BASE_PATH > /dev/null
        git pull
        popd > /dev/null
    fi
    unset PROCEED
fi

cd $BASE_PATH

#
# Download cling
#
heading "Download cling"
if [ -f /etc/os-release ]; then
OS_NAME=$(cat /etc/os-release | sed -r 's/^NAME=["]{0,1}([^"]+)["]{0,1}/\1/;t;d')
if [ "$OS_NAME" = "Ubuntu" ]; then
  notice "Found Ubuntu operating system"
  lsb_release -a 2>&1 | sed -r -e 's/Description:[\t]//;t;d' | grep Ubuntu > /dev/null

  # determine MAJOR_RELEASE version number
  MAJOR_RELEASE=$(lsb_release -a 2>&1 | sed -r -e 's/Release:[\t]//;t;d' | sed -re 's/([0-9]+)\.[0-9]+/\1/')
  if (( $MAJOR_RELEASE % 2 != 0 )); then
      MAJOR_RELEASE=$(($MAJOR_RELEASE-1))
      echo "You are using a non LTS release of ubuntu. This is not officially supported. Falling back to $MAJOR_RELEASE"
  fi

  # determine url
  CLING_BINARY_RELEASE_FILENAME="cling_${CLING_BINARY_RELEASE_DATE}_ubuntu${MAJOR_RELEASE}.tar.bz2"
  CLING_BINARY_DOWNLOAD_URL="https://root.cern.ch/download/cling/${CLING_BINARY_RELEASE_FILENAME}"

  # todo: test that url is valid
elif [ "$OS_NAME" = "Fedora" ]; then
  notice "Found operating system Fedora"
  RELEASE=$(cat /etc/fedora-release | sed -r 's/Fedora release ([0-9]+).*/\1/')
  if [ "$RELEASE" -eq "28" ] || [ "$RELEASE" -eq "29" ]; then
    # todo: check if binary for fedora 28/29 is available
    RELEASE="27"
  fi
  CLING_BINARY_RELEASE_FILENAME="cling_${CLING_BINARY_RELEASE_DATE}_fedora${RELEASE}.tar.bz2"
  CLING_BINARY_DOWNLOAD_URL="https://root.cern.ch/download/cling/${CLING_BINARY_RELEASE_FILENAME}"
  echo $CLING_BINARY_DOWNLOAD_URL
else
  error "Operating system $OS_NAME not supported"
fi

else
  error "Operating system not supported"
fi

if [ -f /tmp/$CLING_BINARY_RELEASE_FILENAME ]; then
  notice "Found existing cling package download. Skipping download."
else
  # todo: this doesn't work right now
  #wget --directory-prefix=/tmp --progress=bar:force $CLING_BINARY_DOWNLOAD_URL 2>&1 | progressfilt
  wget --directory-prefix=/tmp --progress=bar:force $CLING_BINARY_DOWNLOAD_URL
  if [ $? -ne 0 ]; then
    error "Download failed."
  fi
fi

notice "Extracting $CLING_BINARY_RELEASE_FILENAME"
if [ -d bin/cling ]; then
    notice "Found existing cling package download. Skipping extraction."
else
    mkdir -p bin/cling
    tar jxf /tmp/$CLING_BINARY_RELEASE_FILENAME -C bin/cling --strip-components 1
fi

# Compile
heading "Compile plugin"
mkdir -p build
pushd build > /dev/null
cmake ..
make
popd > /dev/null

#
# Add to lldbinit
#
cat ~/.lldbinit 2>/dev/null | grep "$BASE_PATH/plugin/defrustrator.py" > /dev/null
ALREADY_INSTALLED=$?
heading "Adding data formatter to ~/.lldbinit"
if [ ! "$ALREADY_INSTALLED" -eq "0" ]; then
	echo 'command script import "$BASE_PATH/plugin/defrustrator.py"' >> ~/.lldbinit
else
	notice "Skipping"
fi

notice "Installation successful"
