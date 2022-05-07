FROM nvidia/cuda:10.2-devel-ubuntu16.04
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NOWARNINGS yes
RUN apt-get -y update

RUN apt-get install -y --no-install-recommends git pkgconf
WORKDIR /ffmpeg_sources
RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git -b sdk/9.1 && \
    cd nv-codec-headers && \
    make install 
RUN apt-get install -y --no-install-recommends autoconf automake libtool libpng-dev libass-dev
RUN git clone https://github.com/nkoriyama/aribb24.git && \
    cd aribb24 && \
    ./bootstrap && \
    ./configure && \
    make install
RUN apt-get install -y --no-install-recommends build-essential yasm cmake libtool libc6 libc6-dev unzip wget libnuma1 libnuma-dev && \
    git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/ && \
    cd ffmpeg && \
    ./configure --enable-cuda-nvcc --enable-cuvid --enable-nvenc --enable-nonfree --enable-libnpp --enable-version3 --enable-gpl --enable-libaribb24 --enable-libass --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 --disable-static --enable-shared && \
    make install

RUN apt-get install -y --no-install-recommends curl && \
    curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y --no-install-recommends nodejs

WORKDIR /app/client
COPY client/package*.json ./
# どこで時間が掛かっているのか確認できるようにログレベルを変更。
RUN npm install --loglevel=info
COPY client/ .
COPY api.d.ts ../
RUN npm run build --loglevel=info

RUN apt-get install -y --no-install-recommends build-essential python
WORKDIR /app
COPY package*.json ./
RUN npm install --loglevel=info
COPY gulpfile.js .eslintrc.json .prettierrc ormconfig.js api.yml ./
COPY src src
COPY img img
COPY drop drop
RUN npm run build-server --loglevel=info

EXPOSE 8888
WORKDIR /app
ENTRYPOINT ["npm"]
CMD ["start"]
