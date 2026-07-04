#!/usr/bin/env bash
# 최소 static ffmpeg.exe (win64) 빌드 — PyAutoFlow 타임랩스 인코딩 전용.
#
# 이 저장소의 ffmpeg 소스(현재 체크아웃)를 out-of-tree 로 크로스컴파일한다.
# x264 는 소스에서 static 으로 빌드해 재현성·자기완결성 확보(pacman/apt 패키지 의존 X).
#
# 결과물: out/ffmpeg.exe — 딱 필요한 것만 담아 ~2-5MB (범용 배포판 88MB 대비).
#   입력: BMP/PNG 이미지 시퀀스(image2 demuxer)
#   출력: H.264(libx264) mp4, yuv420p
#   필터: scale/format/fps (짝수 해상도·픽셀포맷 변환)
#   진행: -progress pipe:1  → pipe 프로토콜
#
# GPL: libx264 링크 → 결과물 GPL. 이 스크립트 + repo 소스가 대응 소스.
# 실행: ubuntu 에서 mingw-w64 크로스툴체인으로. (scripts/ 는 repo 루트 기준 상대경로 사용)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD="$ROOT/.build"
PREFIX="$BUILD/win"
X264_BRANCH="${X264_BRANCH:-stable}"
mkdir -p "$PREFIX"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

echo "=== [1/3] x264 (static, cross win64) ==="
if [ ! -d "$BUILD/x264" ]; then
  git clone --depth 1 --branch "$X264_BRANCH" https://code.videolan.org/videolan/x264.git "$BUILD/x264"
fi
(
  cd "$BUILD/x264"
  ./configure \
    --host=x86_64-w64-mingw32 \
    --cross-prefix=x86_64-w64-mingw32- \
    --enable-static --disable-cli --disable-opencl \
    --prefix="$PREFIX"
  make -j"$(nproc)"
  make install
)

echo "=== [2/3] configure ffmpeg (minimal, from repo source) ==="
mkdir -p "$BUILD/ffmpeg"
(
  cd "$BUILD/ffmpeg"
  # --disable-everything 후, PyAutoFlow 인코딩 명령이 요구하는 컴포넌트만 켠다:
  #   demuxer image2         : -i frame_%06d.bmp (시퀀스)
  #   decoder bmp,png        : 프레임 디코드(현재 BMP, 향후 PNG 대비)
  #   encoder libx264        : H.264
  #   muxer   mp4            : 컨테이너 (+movflags faststart 는 mp4 muxer 기능)
  #   filter  scale,format   : -vf scale=... + yuv420p 변환(avfilter 필요)
  #   protocol file,pipe     : 파일 + -progress pipe:1
  #   parser h264 / bsf h264_mp4toannexb : mp4 안 H.264 비트스트림(--disable-everything 시 명시 필요)
  PKG_CONFIG=x86_64-w64-mingw32-pkg-config \
  "$ROOT/configure" \
    --target-os=mingw32 --arch=x86_64 \
    --cross-prefix=x86_64-w64-mingw32- --enable-cross-compile \
    --pkg-config=x86_64-w64-mingw32-pkg-config --pkg-config-flags=--static \
    --extra-cflags="-I$PREFIX/include" \
    --extra-ldflags="-L$PREFIX/lib -static" \
    --disable-everything \
    --disable-shared --enable-static \
    --disable-network --disable-doc --disable-debug --disable-autodetect \
    --disable-ffplay --disable-ffprobe \
    --enable-gpl --enable-libx264 --enable-ffmpeg \
    --enable-avcodec --enable-avformat --enable-avutil \
    --enable-avfilter --enable-swscale --enable-swresample \
    --enable-encoder=libx264 \
    --enable-decoder=bmp,png,rawvideo \
    --enable-demuxer=image2,image2pipe \
    --enable-muxer=mp4 \
    --enable-protocol=file,pipe \
    --enable-filter=scale,format,fps,null,copy \
    --enable-parser=h264,png \
    --enable-bsf=h264_mp4toannexb \
    --enable-small

  echo "=== [3/3] make ==="
  make -j"$(nproc)"
  x86_64-w64-mingw32-strip ffmpeg.exe
)

mkdir -p "$ROOT/out"
cp "$BUILD/ffmpeg/ffmpeg.exe" "$ROOT/out/ffmpeg.exe"
echo "=== done → out/ffmpeg.exe ($(du -h "$ROOT/out/ffmpeg.exe" | cut -f1)) ==="
