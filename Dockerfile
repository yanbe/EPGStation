FROM nvidia/cuda:10.2-devel-ubuntu16.04
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,video,utility
WORKDIR /ffmpeg_sources
RUN apt-get -y update && \
    apt-get install -y git pkgconf && \
    git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git -b sdk/9.1 && \
    cd nv-codec-headers && \
    make install 
RUN apt-get install -y build-essential yasm cmake libtool libc6 libc6-dev unzip wget libnuma1 libnuma-dev && \
    git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/ && \
    cd ffmpeg && \
    ./configure --enable-cuda-nvcc --enable-cuvid --enable-nvenc --enable-nonfree --enable-libnpp --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 && \
    make install

RUN apt-get -y update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs

COPY client/package*.json /app/client/
WORKDIR /app/client
# どこで時間が掛かっているのか確認できるようにログレベルを変更。
RUN npm install --loglevel=info
# clientフォルダー外にビルドに必要なファイルが存在するため、全てコピーする。
COPY . /app/
RUN npm run build --loglevel=info

# サーバーはsqlite3のようなプラットフォーム依存のネイティブ・アドオンを含んでいる。そのため、各
# TARGETPLATFORMごとにソースをビルドしなければならない。BUILDPLATFORM以外のTARGETPLATFORMでは、QEMU
# 上でnpmコマンドを実行することになるため、どうしても時間が掛かる。
#
# `npm install`時にネイティブ・アドオンをクロスビルドできればビルド時間を短縮できるが、現時点では明
# 確な手順は存在しない。https://github.com/mapbox/node-pre-gyp/issues/348を見れはそれが分かる。
#
# `npm run build-server`はプラットフォーム依存処理を含まないため、これをBUILDPLATFORMで実行すること
# でビルド時間をさらに短縮可能だが、手順が煩雑で面倒なので現時点では行っていない。
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install -y build-essential python
WORKDIR /app
COPY package*.json /app/
RUN npm install --loglevel=info
# 最終イメージのサイズ削減のため、すべてコピーした後でclientフォルダーを削除。clientフォルダー以外
# をコピーする方法は，ファイルが追加された場合に変更する必要があるため採用しない。
COPY . .
RUN npm run build-server --loglevel=info

EXPOSE 8888
WORKDIR /app
ENTRYPOINT ["npm"]
CMD ["start"]
