#!/bin/bash

# variables
CLING_BINARY_RELEASE_DATE="2020-10-27"

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
  error "cmake not found"
fi

which wget &> /dev/null
if [ $? -ne 0 ]; then
  error "wget not found"
fi

which make &> /dev/null
if [ $? -ne 0 ]; then
  error "make not found"
fi

which tar &> /dev/null
if [ $? -ne 0 ]; then
  error "tar not found"
fi

which bzip2 &> /dev/null
if [ $? -ne 0 ]; then
  error "bzip2 not found"
fi

python -c "import pygments" &> /dev/null
if [ $? -ne 0 ]; then
  echo "pygments not found (install using pip)"
fi

python -c "import prompt_toolkit" &> /dev/null
if [ $? -ne 0 ]; then
  echo "prompt_toolkit not found (install using pip)"
fi

notice "Done."

#
# Download repository
#
heading "Repository Setup"
BASE_PATH="$HOME/.defrustrator"
if [ -d "$(pwd)/.git" ]; then
    pushd "$(pwd)" > /dev/null
    notice "Using BASE_PATH $(pwd)"
    BASE_PATH="$(pwd)"
    popd > /dev/null
fi

BASE_PATH_EXISTS=
if [ ! -d "$BASE_PATH" ]; then
    git clone https://github.com/tehrengruber/Defrustrator.git $BASE_PATH
elif [ -d "$BASE_PATH" ]; then
    pushd $BASE_PATH > /dev/null
    if [ ! -z "$(git status --porcelain)" ]; then
      warn "Repository contains uncommited changes. Skipped update"
      exit 1
    fi
    notice "Update? [yes, no]:"
    read PROCEED
    if [ "$PROCEED" = "yes" ]; then
        notice "Directory $BASE_PATH already exists. Updating."
        git pull
    fi
    unset PROCEED
    popd > /dev/null
fi
cd $BASE_PATH

#
# Download cling
#
heading "Download cling"
if [ -z $CLING_BINARY_DOWNLOAD_URL ]; then
if [ -f /etc/os-release ]; then
OS_NAME=$(cat /etc/os-release | sed -r 's/^NAME=["]{0,1}([^"]+)["]{0,1}/\1/;t;d')
if [ "$OS_NAME" = "Ubuntu" ]; then
  notice "Found Ubuntu operating system"
  lsb_release -a 2>&1 | sed -r -e 's/Description:[\t]//;t;d' | grep Ubuntu > /dev/null

  # determine MAJOR_RELEASE version number
  MAJOR_RELEASE=$(lsb_release -a 2>&1 | sed -r -e 's/Release:[\t]//;t;d' | sed -re 's/([0-9]+)\.([0-9]+)/\1/')
  MINOR_RELEASE=$(lsb_release -a 2>&1 | sed -r -e 's/Release:[\t]//;t;d' | sed -re 's/([0-9]+)\.([0-9]+)/\2/')
  if (( $MAJOR_RELEASE % 2 != 0 )); then
      MAJOR_RELEASE=$(($MAJOR_RELEASE-1))
      echo "You are using a non LTS release of ubuntu. This is not officially supported. Falling back to $MAJOR_RELEASE"
  fi

  if [ "$MAJOR_RELEASE" -eq "20" ]; then
    CLING_BINARY_RELEASE_SUFFIX="$MAJOR_RELEASE$MINOR_RELEASE"
  elif [ "$MAJOR_RELEASE" -eq "18" ]; then
    CLING_BINARY_RELEASE_SUFFIX="$MAJOR_RELEASE.$MINOR_RELEASE"
  else
    CLING_BINARY_RELEASE_SUFFIX="$MAJOR_RELEASE"
  fi

  # determine url
  CLING_BINARY_RELEASE_FILENAME="cling_${CLING_BINARY_RELEASE_DATE}_ROOT-ubuntu${CLING_BINARY_RELEASE_SUFFIX}.tar.bz2"
  CLING_BINARY_DOWNLOAD_URL="https://root.cern.ch/download/cling/${CLING_BINARY_RELEASE_FILENAME}"

  # todo: test that url is valid
elif [ "$OS_NAME" = "Fedora" ]; then
  notice "Found operating system Fedora"
  RELEASE=$(cat /etc/fedora-release | sed -r 's/Fedora release ([0-9]+).*/\1/')
  if [ "$RELEASE" -eq "28" ] || [ "$RELEASE" -eq "29" ]; then
    # todo: check if binary for fedora 28/29 is available
    RELEASE="27"
  fi
  CLING_BINARY_RELEASE_FILENAME="cling_${CLING_BINARY_RELEASE_DATE}_ROOT-fedora${RELEASE}.tar.bz2"
  CLING_BINARY_DOWNLOAD_URL="https://root.cern.ch/download/cling/${CLING_BINARY_RELEASE_FILENAME}"
  echo $CLING_BINARY_DOWNLOAD_URL
else
  error "Operating system $OS_NAME not supported"
fi

else
  error "Operating system not supported"
fi

else
notice "Using user-specified download url: $CLING_BINARY_DOWNLOAD_URL"
CLING_BINARY_RELEASE_FILENAME="${CLING_BINARY_DOWNLOAD_URL##*/}"
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
# Add to .lldbinit
#
cat $HOME/.lldbinit 2>/dev/null | grep "$BASE_PATH/plugin/defrustrator.py" > /dev/null
ALREADY_INSTALLED=$?
heading "Adding plugin to $HOME/.lldbinit"
if [ ! "$ALREADY_INSTALLED" -eq "0" ]; then
	echo "command script import \"$BASE_PATH/plugin/defrustrator.py\"" >> $HOME/.lldbinit
else
	notice "Skipping"
fi

notice "Installation successful"
