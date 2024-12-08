# ----------------------------------------------------------------------
# Dockerfile for Kali-iOS
# 
# Author: Mathieu Renard
# Email: mathieu.renard@twistedwires.io
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# ----------------------------------------------------------------------


FROM gradle:jdk17 as GHIDRABUILDER

RUN apt-get update && apt-get install -y curl git bison flex build-essential unzip

ENV VERSION 11.0.3_PUBLIC
ENV GHIDRA_SHA 2462a2d0ab11e30f9e907cd3b4aa6b48dd2642f325617e3d922c28e752be6761
ENV GHIDRA_URL https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0.3_build/ghidra_11.0.3_PUBLIC_20240410.zip

RUN apt-get update && apt-get install -y fontconfig libxrender1 libxtst6 libxi6 wget unzip python3-requests --no-install-recommends \
    && wget --progress=bar:force -O /tmp/ghidra.zip ${GHIDRA_URL} \
    && echo "$GHIDRA_SHA /tmp/ghidra.zip" | sha256sum -c - \
    && unzip /tmp/ghidra.zip \
    && mv ghidra_${VERSION} /ghidra \
    && chmod +x /ghidra/ghidraRun \
    && echo "===> Clean up unnecessary files..." \
    && apt-get purge -y --auto-remove wget unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives /tmp/* /var/tmp/* /ghidra/docs /ghidra/Extensions/Eclipse /ghidra/licenses

RUN /ghidra/support/buildNatives

FROM golang:1.22 as IPSWBUILDER

RUN git clone https://github.com/blacktop/ipsw /opt/ipsw
WORKDIR /opt/ipsw

RUN CGO_ENABLED=1 go build \
    -o /bin/ipsw \
    ./cmd/ipsw


FROM kalilinux/kali-rolling as KALI-IOS

# Define the SDK version to download as a build argument with a default value
ARG DEBIAN_FRONTEND=noninteractive
ARG SDK_VERSION=iPhoneOS14.4.sdk
ENV SDK_VERSION=${SDK_VERSION}

# Optional: Path to a local SDK tarball
ARG SDK_PATH
ENV SDK_PATH=${SDK_PATH}


# Install necessary packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
libfuse3-dev bzip2 libbz2-dev libz-dev cmake build-essential git libattr1-dev \
fuse3 unzip lzma tzdata xz-utils \
curl git bison flex build-essential unzip \
fontconfig libxrender1 libxtst6 libxi6 openjdk-17-jdk-headless \
xfonts-base xserver-xorg-input-all xinit xserver-xorg xserver-xorg-video-all \
    liblzfse-dev \ 
    unrar \
    sqlcipher \
    sqlite3 \
    libfuse-dev \
    libbz2-dev \
    libicu-dev \
    libxml2-dev  \
    libssl-dev \
    libz-dev \
    libavahi-client-dev \
    vim \
    openssh-server \
    libusbmuxd-tools \ 
    socat \
    clang \
    git \
    openssl \
    cmake \
    libtool \	
    pkg-config \
	checkinstall \
	git \
	autoconf \
	automake \
	libtool-bin \
	libplist-dev \
    colormake \ 
    automake \
    libplist-dev \
    autotools-dev \
    libimobiledevice-1.0-6 \
    usbmuxd \
     avahi-daemon \
    curl \
    sudo \
    zsh \
    python3-pip \
    libusb-1.0-0-dev \
    usbmuxd \
    libimobiledevice-utils \
    libimobiledevice-dev \
    libplist-utils \
    ipython3 \
    python3-notebook \
    build-essential \
    pkg-config \
    fakeroot \
    perl \
    wget \
    ideviceinstaller \
    libcurl4-gnutls-dev \
    afl++ \
    unzip  

# Install additional tools
RUN pip3 install frida-tools \
    sark \
    pymobiledevice3 \
    jupyter \
    capstone \
    objection \
    lief  

RUN git clone https://github.com/GotoHack/ios-deploy.git /opt/ios-deploy  && \
    cd /opt/ios-deploy && make && ln -s /opt/ios-deploy/ios-deploy /usr/local/bin/ 


RUN cd /opt \
    && git clone https://github.com/sgan81/apfs-fuse.git \
    && cd apfs-fuse \
    && git submodule init \
    && git submodule update \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make install


USER root
# TODO modify the root password
RUN echo "root:ios" | chpasswd


# Install Theos
ENV THEOS /opt/theos
RUN git clone --recursive https://github.com/theos/theos.git $THEOS
ENV PATH "$THEOS/bin:$PATH"

# Setup SSH
RUN mkdir /var/run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Set default shell to Zsh
RUN chsh -s /usr/bin/zsh

# Expose port 22 for SSH connection and port 8888 for Jupyter Notebook
EXPOSE 22 5000 8888 13100 13101 13102

# Setup the working directory
WORKDIR /root

# Configure Jupyter Notebook to run without password or token and allow root access
RUN jupyter notebook --generate-config && \
    echo "c.NotebookApp.allow_root = True" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.token = ''" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.password = ''" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> /root/.jupyter/jupyter_notebook_config.py

# Clone cctools-port
RUN git clone https://github.com/tpoechtrager/cctools-port.git /opt/ios_toolchain/cctools-port

# Build the iOS cross-compiler toolchain
RUN     echo "Downloading SDK from GitHub..." && \
        curl -L https://github.com/GrowtopiaJaw/iPhoneOS-SDK/releases/download/v1.0/${SDK_VERSION}.tar.xz -o /tmp/${SDK_VERSION}.tar.xz && \
        echo "Using downloaded SDK tarball for build..." && \
        cd /opt/ios_toolchain/cctools-port/usage_examples/ios_toolchain && \
        ./build.sh /tmp/${SDK_VERSION}.tar.xz arm64

# Darling-dmg (requires building from source)
RUN git clone --recursive https://github.com/darlinghq/darling-dmg.git /opt/darling-dmg && \
    mkdir /opt/darling-dmg/build && \
    cd /opt/darling-dmg/build && \
    cmake .. && \
    make && \
    make install

# img4tool, partial-zip, ipsw (these may require manual installation or building from source)
RUN git clone https://github.com/libimobiledevice/libplist /opt/libplist
RUN cd /opt/libplist && ./autogen.sh && make && make install 

RUN git clone https://github.com/tihmstar/libgeneral /opt/libgeneral
RUN cd /opt/libgeneral && ./autogen.sh --prefix=/usr/ --with-static-libplist=/usr/local/lib/libplist-2.0.a && make && make install

RUN git clone https://github.com/tihmstar/libfragmentzip /opt/libfragmentzip
RUN cd /opt/libfragmentzip && ./autogen.sh --prefix=/usr/ && make && make install

RUN git clone https://github.com/tihmstar/partialZipBrowser.git /opt/partial-zip
RUN cd /opt/partial-zip && ./autogen.sh --prefix=/usr/ && make && make install


RUN git clone https://github.com/sbingner/ldid.git /opt/ldid
RUN cd /opt/ldid && make && make install
    
# Clone and build usbfluxd
RUN git clone https://github.com/corellium/usbfluxd.git /opt/usbfluxd
RUN cd /opt/usbfluxd && ./autogen.sh --with-static-libplist=/usr/local/lib/libplist-2.0.a && make && make install



RUN git clone https://github.com/tihmstar/img4tool.git /opt/img4tool
RUN cd /opt/img4tool && ./autogen.sh --prefix=/usr/ --with-static-libplist=/usr/local/lib/libplist-2.0.a && make && make install

RUN libtool --finish /usr/local/lib

RUN python3 -m pip install dyldextractor

RUN curl -L https://assets.checkra.in/downloads/linux/cli/x86_64/dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d/checkra1n -o /tmp/checkra1n.x86_64 
RUN curl -L https://assets.checkra.in/downloads/linux/cli/arm64/43019a573ab1c866fe88edb1f2dd5bb38b0caf135533ee0d6e3ed720256b89d0/checkra1n -o /tmp/checkra1n.aarch64
RUN cp /tmp/checkra1n* /usr/local/bin && chmod 777 /usr/local/bin/checkra1n*

RUN /bin/sh -c "$(curl -fsSL https://static.palera.in/scripts/install.sh)"

#RUN curl -L  https://cydia.saurik.com/api/latest/5 -o /tmp/Impactor64.tgz
#RUN mkdir -p /opt/impactor/ cd /opt/impactor && tar -xvf  /tmp/Impactor64.tgz

RUN curl -sL http://nah6.com/~itsme/cvs-xdadevtools/iphone/tools/lzssdec.cpp -o /tmp/lzssdec.cpp \
    && g++ -o /usr/local/bin/lzssdec /tmp/lzssdec.cpp \
    && echo "Installed lzssdec to /usr/local/bin"

RUN git clone https://github.com/joxeankoret/diaphora /opt/diaphora


RUN curl -L http://www.newosxbook.com/tools/jtool.tar -o /tmp/jtool.tar \
    && tar -xvf /tmp/jtool.tar -C /usr/local/bin \
    && rm /usr/local/bin/jtool \
    && mv /usr/local/bin/jtool.ELF64 /usr/local/bin/jtool \
    && echo "Installed jtool to /usr/local/bin"

# Function to install joker
RUN curl -L http://www.newosxbook.com/tools/joker.tar -o /tmp/joker.tar \
    && tar -xvf /tmp/joker.tar -C /usr/local/bin \
    && mv /usr/local/bin/joker.ELF64 /usr/local/bin/joker \
    && echo "Installed joker to /usr/local/bin"

# Function to install disarm
RUN curl -L http://newosxbook.com/tools/disarm.tar -o /tmp/disarm.tar \
    && cd /tmp && tar -xvf /tmp/disarm.tar && cd /tmp/binaries && cp -v disarm.ELF64*  /usr/local/bin \
    && echo "Installed disarm to /usr/local/bin"

# Function to install OTA stuff
RUN git clone https://gist.github.com/683ec721655f3729f9fad23b052384e3.git /opt/pbzx \
    && cd /opt/pbzx \
    && gcc pbzx.c -o pbzx \
    && cd .. \
    && git clone https://gist.github.com/be2a4f32a3ba49ad477b34292d728914.git /opt/ota \
    && cd /opt/ota \
    && gcc ota.c -o ota \
    && cp /opt/pbzx/pbzx /opt/ota/ota /usr/local/bin \
    && echo "Installed OTA stuff to /usr/local/bin"


# Download apple developper disk image
RUN for DVER in 15.7 15.6.1 15.6 15.5 15.4 15.3.1 15.3 15.2 15.1 15.0 14.7.1 14.7 14.6 14.5 14.4 14.3 14.2 14.1; do curl -L https://github.com/mspvirajpatel/Xcode_Developer_Disk_Images/releases/download/$DVER/$DVER.zip -o /tmp/$DVER.zip && mkdir -p ./DDI/$DVER && cd ./DDI/$DVER && unzip /tmp/$DVER.zip && rm /tmp/$DVER.zip && cd -; done

ENV PATH /opt/ios_toolchain/cctools-port/usage_examples/ios_toolchain/target/bin:$PATH
ENV LD_LIBRARY_PATH /opt/ios_toolchain/cctools-port/usage_examples/ios_toolchain/target/lib:$LD_LIBRARY_PATH


ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
ENV IPSW_IN_DOCKER=1
COPY --from=IPSWBUILDER /bin/ipsw /bin/ipsw
COPY --from=GHIDRABUILDER /ghidra /ghidra

# Start SSH service, usbfluxd, and Jupyter Notebook on container start
CMD ["/bin/zsh", "-c", "/usr/sbin/sshd -D & usbmuxd & jupyter notebook --no-browser --port=8888 --ip=0.0.0.0"]
#CMD ["/bin/zsh", "-c", "/usr/sbin/sshd -D & jupyter notebook --no-browser --port=8888 --ip=0.0.0.0"]
