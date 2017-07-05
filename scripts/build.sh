#!/bin/bash
set -e

SCRIPT=$(readlink -f "$0")
SCRIPTDIR=$(dirname "${SCRIPT}")
WORKDIR=${PWD}

# Load helper functions
source "${SCRIPTDIR}/functions.sh"

# Initialize Qt environment
set +e
source "/opt/qt59/bin/qt59-env.sh"
set -e

# Define build variables
APP="Plex Media Player"
LOWERAPP="plexmediaplayer"
DATE=$(date -u +'%Y%m%d')

case "$(uname -i)" in
  x86_64|amd64)
    SYSTEM_ARCH="x86_64"
    SYSTEM_ARCHX="x86-64";;
  i?86)
    SYSTEM_ARCH="i686"
    SYSTEM_ARCHX="x86";;
  *)
    echo "Unsupported system architecture"
    exit 1;;
esac
echo "System architecture: ${SYSTEM_ARCHX}"

case "${ARCH:-$(uname -i)}" in
  x86_64|amd64)
    TARGET_ARCH="x86_64"
    PLATFORM="x86-64";;
  i?86)
    TARGET_ARCH="i686"
    PLATFORM="x86";;
  *)
    echo "Unsupported target architecture"
    exit 1;;
esac
echo "Target architecture: ${PLATFORM}"

# Build mpv player
cd "${WORKDIR}"
if [ -d mpv-build ]; then
  cd mpv-build
  git clean -xf
  git checkout master
  git pull
else
  git clone https://github.com/mpv-player/mpv-build.git
  cd mpv-build
fi

echo "--prefix=/usr" > mpv_options
echo "--enable-libmpv-shared" >> mpv_options
echo "--disable-cplayer" >> mpv_options
./rebuild
./install

# Build Plex Media Player
cd "${WORKDIR}"
if [ -d plex-media-player ]; then
  cd plex-media-player
  git clean -xf
  git checkout master
  git pull
else
  git clone https://github.com/plexinc/plex-media-player.git
  cd plex-media-player
fi

# If building from tag use a specific version of Plex Media Player sources
if [ -n "${TRAVIS_TAG}" ]; then
  git checkout ${TRAVIS_TAG}
fi
COMMIT_HASH=$(git log -n 1 --pretty=format:'%h' --abbrev=8)

# Set package version string to tag name or if not present to current date with commit hash
VERSION="${TRAVIS_TAG:-${DATE}_${COMMIT_HASH}}"

rm -rf build 
mkdir -p build
cd build
conan install ..
cmake -DCMAKE_BUILD_TYPE=Release -DQTROOT="${QTDIR}" -DCMAKE_INSTALL_PREFIX=/usr ..
make
mkdir -p install
make install DESTDIR=install

# Prepare working directory
cd "${WORKDIR}"
mkdir -p "appimage"
cd "appimage"
download_linuxdeployqt

# Initialize AppDir
rm -rf "AppDir"
mkdir "AppDir"
APPDIR="${PWD}/AppDir"

# Copy binaries
cp -pr "${WORKDIR}/plex-media-player/build/install/"* "${APPDIR}"
ln -s "../share/plexmediaplayer/web-client" "${APPDIR}/usr/bin/web-client"

# Setup desktop integration (launcher, icon, menu entry)
cp "${WORKDIR}/plexmediaplayer.desktop" "${APPDIR}/${LOWERAPP}.desktop"
cp "${WORKDIR}/plex-media-player/resources/images/icon.png" "${APPDIR}/${LOWERAPP}.png"

cd "${APPDIR}"
get_apprun
get_desktopintegration ${LOWERAPP}
cd "${OLDPWD}"

# Create AppImage bundle
cd "${WORKDIR}/appimage"
if [[ "${VERSION}" =~ ^v[0-9]+\.[0-9]+ ]]; then
  VERSION=${VERSION:1}
fi
APPIMAGE_FILE_NAME="Plex_Media_Player_${VERSION}_${PLATFORM}.AppImage"
echo "${APPIMAGE_FILE_NAME}"
./linuxdeployqt "${APPDIR}/usr/bin/plexmediaplayer" -bundle-non-qt-libs
./linuxdeployqt "${APPDIR}/usr/bin/plexmediaplayer" -qmldir="../plex-media-player/src/ui" -appimage
mv *.AppImage "${WORKDIR}/${APPIMAGE_FILE_NAME}"

cd "${WORKDIR}"
sha1sum *.AppImage