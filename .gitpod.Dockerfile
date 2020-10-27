FROM gitpod/workspace-full

USER root

RUN apt-get update -qq && \
    apt-get install -qq -y wget git cmake g++ lldb libeigen3-dev

USER gitpod

RUN bash -c "$(wget https://raw.githubusercontent.com/tehrengruber/Defrustrator/master/scripts/install.sh -O -)"

