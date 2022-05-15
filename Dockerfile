FROM nvidia/cuda:10.2-devel-ubuntu16.04
LABEL Name="EPGStation with NVENC-enabled FFmpeg"
LABEL Version=0.0.1

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NOWARNINGS yes

# Build EPGStation client
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean

WORKDIR /app/client
COPY client/package*.json ./
# どこで時間が掛かっているのか確認できるようにログレベルを変更。
RUN npm install --loglevel=info
COPY client/ .
COPY api.d.ts ../
RUN npm run build --loglevel=info

# Build EPGStation Server
RUN apt-get install -y --no-install-recommends build-essential python && apt-get clean
WORKDIR /app
COPY package*.json ./
RUN npm install --loglevel=info
COPY gulpfile.js .eslintrc.json .prettierrc ormconfig.js api.yml ./
COPY src src
COPY img img
COPY drop drop
RUN npm run build-server --loglevel=info

# build FFmpeg
RUN apt-get install -y --no-install-recommends git pkgconf && apt-get clean
WORKDIR /ffmpeg_sources
RUN git clone https://github.com/FFmpeg/nv-codec-headers.git -b sdk/10.0 && \
    cd nv-codec-headers && \
    make install 
RUN apt-get install -y --no-install-recommends autoconf automake libtool libpng-dev libass-dev && apt-get clean
RUN git clone https://github.com/nkoriyama/aribb24.git && \
    cd aribb24 && \
    ./bootstrap && \
    ./configure && \
    make install
RUN apt-get install -y --no-install-recommends build-essential yasm cmake libtool libc6 libc6-dev unzip wget libnuma1 libnuma-dev && \
    git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/ && \
    cd ffmpeg && \
    ./configure \
        --disable-everything \
        --enable-cuda-nvcc \
        --enable-cuda-llvm \
        --enable-nvdec \
        --enable-nvenc \
        --enable-nonfree \
        --enable-libnpp \
        --enable-version3 \
        --enable-gpl \
        --enable-libaribb24 \
        --enable-libass \
        --enable-protocol=file \
        --enable-demuxer=mpegts \
        --enable-demuxer=mp4 \
        --enable-demuxer=matroska \
        --enable-decoder=aac \
        --enable-decoder=libaribb24 \
        --enable-filter=ass \
        --enable-filter=yadif_cuda \
        --enable-encoder=aac \
        --enable-muxer=hls \
        --enable-muxer=mp4 \
        --enable-muxer=matroska \
        --extra-cflags=-I/usr/local/cuda/include \
        --extra-ldflags=-L/usr/local/cuda/lib64 \
        --nvccflags="-gencode arch=compute_30,code=sm_30 -O2" && \
    make install && \
    apt-get clean

EXPOSE 8888
WORKDIR /app
ENTRYPOINT ["npm"]
CMD ["start"]
