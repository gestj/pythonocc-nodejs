ARG PYTHON_VERSION=3.9

FROM python:$PYTHON_VERSION-slim as build
MAINTAINER Johannes Gest <kiiu.rib@gmail.com>

ARG DEBIAN_FRONTEND=noninteractive

ARG OCCT_VERSION=V7_7_0
ARG PYTHON_OCC_CORE_VERSION=7.7.0
ARG SWIG_VERSION=4.0.2
ARG TBB_VERSION=2021.7.0

RUN apt-get update && apt-get install -qq  \
    build-essential  \
    cmake \
    git \
    wget && \
    pip install --upgrade pip

# TBB is built because OCCT did complain about version of `libtbb-dev` (it was too old)
# building oneTBB (dependency for OCCT)
# https://github.com/oneapi-src/oneTBB/blob/master/INSTALL.md
WORKDIR /
RUN \
    git clone --depth=1 --branch=v$TBB_VERSION https://github.com/oneapi-src/oneTBB.git src-tbb && \
    mkdir src-tbb/build
WORKDIR /src-tbb/build
RUN cmake ..\
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/tbb \
      -DTBB_TEST=OFF && \
    cmake --build . && cmake --install .

# building occt
WORKDIR /
RUN apt-get install -qq \
      libfreeimage-dev \
      libfreetype6-dev \
      libglfw3-dev \
      libglu1-mesa-dev \
      libgl1-mesa-dev \
      libx11-dev \
      libxi-dev \
      libxmu-dev \
      tcl \
      tcl-dev \
      tk \
      tk-dev && \
    git clone --depth=1 --branch=$OCCT_VERSION https://git.dev.opencascade.org/repos/occt.git src-occt && \
    mkdir src-occt/build
WORKDIR /src-occt/build
RUN cmake ..\
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/occt  \
      -DOCCT_MMGT_OPT_DEFAULT=1 \
      -DUSE_FREETYPE=true \
      -DUSE_FREEIMAGE=true \
      -DUSE_OPENVR=false \
      -DUSE_OPENGL=true \
      -DUSE_GLES32=false \
      -DUSE_RAPIDJSON=false \
      -DUSE_DRACO=false \
      -DUSE_TK=true \
      -DUSE_TBB=true \
      -DUSE_VTK=false \
      -D3RDPARTY_TBB=/usr/tbb && \
    make -j4 && make -j4 install

# building swig (dependency for pythonocc-core)
WORKDIR /
RUN \
  apt-get install -qq  \
    automake \
    byacc \
    libpcre3-dev && \
  wget --show-progress https://github.com/swig/swig/archive/refs/tags/v$SWIG_VERSION.tar.gz && \
  tar -xf v$SWIG_VERSION.tar.gz
WORKDIR /swig-$SWIG_VERSION
RUN ls -la && ./autogen.sh && ./configure && make && make install

# building pythonocc-core
WORKDIR /
RUN \
    git clone https://github.com/Tencent/rapidjson.git && mv rapidjson/include/rapidjson /usr/local/include/rapidjson && rm -rf /rapidjson && \
    wget --show-progress https://github.com/tpaviot/pythonocc-core/archive/refs/tags/$PYTHON_OCC_CORE_VERSION.tar.gz && \
    tar -xf $PYTHON_OCC_CORE_VERSION.tar.gz && mkdir pythonocc-core-$PYTHON_OCC_CORE_VERSION/build
WORKDIR /pythonocc-core-$PYTHON_OCC_CORE_VERSION/build
RUN ls -la /usr/occt
RUN cmake ..\
      -DCMAKE_BUILD_TYPE=Release \
      -DOCE_LIB_PATH=/usr/occt/lib \
      -DOCE_INCLUDE_PATH=/usr/occt/include/opencascade && \
    make -j4 && make -j4 install


FROM python:$PYTHON_VERSION-slim as main
MAINTAINER Johannes Gest <kiiu.rib@gmail.com>

ARG DEBIAN_FRONTEND=noninteractive

ARG NODE_VERSION=19.6.0
ARG NPM_VERSION=9.4.0

COPY --from=build /usr/occt /usr/local
COPY --from=build /usr/tbb /usr/local
COPY --from=build /usr/local/lib/python3.9/site-packages/OCC /usr/local/lib/python3.9/site-packages/OCC

# Adding node-js to this image is inspired by https://github.com/nikolaik/docker-python-nodejs/blob/main/templates/debian.Dockerfile
#
# AND adding OCCT runtime dependencies:
# - FreeType
# - FreeImage
# - see https://dev.opencascade.org/doc/overview/html/index.html#intro_req_libs for more details)
#
# AND adding pythonocc runtime dependencies:
# - six
RUN \
    apt-get update && apt-get install -y \
      gnupg2 \
      libfreeimage-dev \
      libfreetype6-dev \
      wget  \
      xvfb && \
    echo "deb https://deb.nodesource.com/node_$NODE_VERSION.x bullseye main" > /etc/apt/sources.list.d/nodesource.list && \
    wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    wget -qO- https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -qq nodejs=$(apt-cache show nodejs|grep Version|grep nodesource|cut -c 10-) && \
    npm i -g npm@^$NPM_VERSION && \
    pip install --upgrade pip && pip install six && \
    apt-get --auto-remove -y purge \
      gnupg2 \
      wget && \
    rm -rf /var/lib/apt/lists/*

ENV DISPLAY=:0
ENV PYTHONOCC_OFFSCREEN_RENDERER=1
