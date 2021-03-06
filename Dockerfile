FROM ubuntu:18.04

# ------------------------------------------------------
# --- Environments and base directories

# Environments
# - Language
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
# - CI
    CI="true" \
# Configs - tool versions
    TOOL_VER_RUBY="2.5.1" \
    TOOL_VER_GO="1.10.3" \
    TOOL_VER_DOCKER="18.03.1" \
    TOOL_VER_DOCKER_COMPOSE="1.21.2" \
# Android
	ANDROID_HOME="/opt/android-sdk-linux"


# ------------------------------------------------------
# --- Base pre-installed tools
RUN apt-get update -qq

# Generate proper EN US UTF-8 locale
# Install the "locales" package - required for locale-gen
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    locales \
# Do Locale gen
 && locale-gen en_US.UTF-8


RUN DEBIAN_FRONTEND=noninteractive apt-get -y install \
# Requiered for Bitrise CLI
    git \
    mercurial \
    curl \
    wget \
    rsync \
    sudo \
    expect \
# Python
    python \
    python-dev \
    python-pip \
# Common, useful
    build-essential \
    zip \
    unzip \
    tree \
    clang \
    imagemagick \
    awscli \
# For PPAs
    software-properties-common



# ------------------------------------------------------
# --- Pre-installed but not through apt-get

# install Ruby from source
#  from source: mainly because of GEM native extensions,
#  this is the most reliable way to use Ruby on Ubuntu if GEM native extensions are required
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install \
    build-essential \
    zlib1g-dev \
    libssl-dev \
    libreadline6-dev \
    libyaml-dev \
    libsqlite3-dev \
 && mkdir -p /tmp/ruby-inst \
 && cd /tmp/ruby-inst \
 && wget -q http://cache.ruby-lang.org/pub/ruby/ruby-${TOOL_VER_RUBY}.tar.gz \
 && tar -xvzf ruby-${TOOL_VER_RUBY}.tar.gz \
 && cd ruby-${TOOL_VER_RUBY} \
 && ./configure --prefix=/usr/local && make && make install \
# cleanup
 && cd / \
 && rm -rf /tmp/ruby-inst \
 && gem update --system --no-document
 RUN [ -x "$(command -v bundle)" ] || gem install bundler --no-document


# install Go
#  from official binary package
RUN wget -q https://storage.googleapis.com/golang/go${TOOL_VER_GO}.linux-amd64.tar.gz -O go-bins.tar.gz \
 && tar -C /usr/local -xvzf go-bins.tar.gz \
 && rm go-bins.tar.gz
# ENV setup
ENV PATH $PATH:/usr/local/go/bin
# Go Workspace dirs & envs
# From the official Golang Dockerfile
#  https://github.com/docker-library/golang
ENV GOPATH /bitrise/go
ENV PATH $GOPATH/bin:$PATH
# 755 because Ruby complains if 777 (warning: Insecure world writable dir ... in PATH)
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 755 "$GOPATH"


# Install NodeJS
#  from official docs: https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
RUN sudo apt-get install -y nodejs


# Install Yarn
# as described at: https://yarnpkg.com/en/docs/install#linux-tab
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN DEBIAN_FRONTEND=noninteractive apt-get update -qq && sudo apt-get install -y yarn


# Install docker
#  as described at: https://docs.docker.com/engine/installation/linux/ubuntu/
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-transport-https \
    ca-certificates
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
RUN sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
 && DEBIAN_FRONTEND=noninteractive apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-cache policy docker-ce \
# For available docker-ce versions
#  you can run `sudo apt-get update && sudo apt-cache policy docker-ce`
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce=${TOOL_VER_DOCKER}~ce~3-0~ubuntu


# docker-compose
RUN wget -q https://github.com/docker/compose/releases/download/${TOOL_VER_DOCKER_COMPOSE}/docker-compose-`uname -s`-`uname -m` -O /usr/local/bin/docker-compose \
 && chmod +x /usr/local/bin/docker-compose \
 && docker-compose --version



# ------------------------------------------------------
# --- SSH config

COPY ./ssh/config /root/.ssh/config



# ------------------------------------------------------
# --- Git config

RUN git config --global user.email builds@jenkins_iig.io \
 && git config --global user.name "IIG Jenkins Bot"



# ------------------------------------------------------
# --- Git LFS

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install git-lfs \
 && git lfs install



# ------------------------------------------------------
# --- Install required tools

RUN apt-get update -qq

# Base (non android specific) tools
# -> should be added to bitriseio/docker-bitrise-base

# Dependencies to execute Android builds
RUN dpkg --add-architecture i386
RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk libc6:i386 libstdc++6:i386 libgcc1:i386 libncurses5:i386 libz1:i386



# ------------------------------------------------------
# --- Download Android SDK tools into $ANDROID_HOME

RUN cd /opt \
    && wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O android-sdk-tools.zip \
    && unzip -q android-sdk-tools.zip -d ${ANDROID_HOME} \
    && rm android-sdk-tools.zip

ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools



# ------------------------------------------------------
# --- Install Android SDKs and other build packages

# Other tools and resources of Android SDK
#  you should only install the packages you need!
# To get a full list of available options you can use:
#  sdkmanager --list

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses

# Platform tools
RUN sdkmanager "emulator" "tools" "platform-tools"

# SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.

# Please keep all sections in descending order!
RUN yes | sdkmanager \
    "platforms;android-28" \
    "platforms;android-27" \
    "platforms;android-26" \
    "platforms;android-25" \
    "platforms;android-24" \
    "platforms;android-23" \
    "platforms;android-22" \
    "platforms;android-21" \
    "platforms;android-19" \
    "platforms;android-17" \
    "platforms;android-15" \
    "build-tools;28.0.1" \
    "build-tools;28.0.0" \
    "build-tools;27.0.3" \
    "build-tools;27.0.2" \
    "build-tools;27.0.1" \
    "build-tools;27.0.0" \
    "build-tools;26.0.2" \
    "build-tools;26.0.1" \
    "build-tools;25.0.3" \
    "build-tools;24.0.3" \
    "build-tools;23.0.3" \
    "build-tools;22.0.1" \
    "build-tools;21.1.2" \
    "build-tools;19.1.0" \
    "build-tools;17.0.0" \
    "system-images;android-26;google_apis;x86" \
    "system-images;android-25;google_apis;armeabi-v7a" \
    "system-images;android-24;default;armeabi-v7a" \
    "system-images;android-22;default;armeabi-v7a" \
    "system-images;android-19;default;armeabi-v7a" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "extras;google;google_play_services" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.2" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.1" \
    "add-ons;addon-google_apis-google-24" \
    "add-ons;addon-google_apis-google-23" \
    "add-ons;addon-google_apis-google-22" \
    "add-ons;addon-google_apis-google-21"

# ------------------------------------------------------
# --- Install Gradle from PPA

# Gradle PPA
RUN apt-get update \
 && apt-get -y install gradle \
 && gradle -v

# ------------------------------------------------------
# --- Install Maven 3 from PPA

RUN apt-get purge maven maven2 \
 && apt-get update \
 && apt-get -y install maven \
 && mvn --version


# ------------------------------------------------------
# --- Pre-install Ionic and Cordova CLIs

RUN npm install -g ionic cordova


# ------------------------------------------------------
# --- Install Fastlane

RUN gem install fastlane --no-document \
 && fastlane --version

# ------------------------------------------------------
# --- Install Google Cloud SDK
# https://cloud.google.com/sdk/downloads
#  Section: apt-get (Debian and Ubuntu only)
#
# E.g. for "Using Firebase Test Lab for Android from the gcloud Command Line":
#  https://firebase.google.com/docs/test-lab/command-line
#

RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk-`lsb_release -c -s` main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
RUN sudo apt-get update -qq \
 && sudo apt-get install -y -qq google-cloud-sdk

ENV GCLOUD_SDK_CONFIG /usr/lib/google-cloud-sdk/lib/googlecloudsdk/core/config.json

# gcloud config doesn't update config.json. See the official Dockerfile for details:
#  https://github.com/GoogleCloudPlatform/cloud-sdk-docker/blob/master/Dockerfile
RUN /usr/bin/gcloud config set --installation component_manager/disable_update_check true \
 && sed -i -- 's/\"disable_updater\": false/\"disable_updater\": true/g' $GCLOUD_SDK_CONFIG \
 && /usr/bin/gcloud config set --installation core/disable_usage_reporting true \
 && sed -i -- 's/\"disable_usage_reporting\": false/\"disable_usage_reporting\": true/g' $GCLOUD_SDK_CONFIG



# ------------------------------------------------------
# --- Install additional packages

# Required for Android ARM Emulator
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libqt5widgets5
ENV QT_QPA_PLATFORM offscreen
ENV LD_LIBRARY_PATH ${ANDROID_HOME}/tools/lib64:${ANDROID_HOME}/emulator/lib64:${ANDROID_HOME}/emulator/lib64/qt/lib



# ------------------------------------------------------
# --- Cleanup and rev num

# Cleaning
RUN apt-get clean
