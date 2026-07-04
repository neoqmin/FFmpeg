# PyAutoFlow 최소 ffmpeg 빌드

PyAutoFlow 코딩 타임랩스 인코딩 전용으로, **딱 필요한 것만 담은 최소 static `ffmpeg.exe`(win64)** 를
이 저장소의 ffmpeg 소스에서 빌드해 GitHub Release 로 배포한다.

- 범용 배포판(≈88MB) 대신 **≈2–5MB** — 앱이 다운로드-온-디맨드로 받아 캐시하는 부담을 줄이기 위함.
- 포함: `libx264`(H.264) · `mp4` muxer · `image2` demuxer · `bmp`/`png` decoder ·
  `scale`/`format`/`fps` filter · `yuv420p`. 그 외 코덱/포맷은 대부분 비활성.
- **범용 ffmpeg 가 아니다.** PyAutoFlow 인코딩 명령 외에는 대부분 동작하지 않는다.

## 빌드

```bash
bash scripts/build-min-win64.sh   # → out/ffmpeg.exe (mingw-w64 크로스컴파일, ubuntu)
```

x264 는 소스에서 static 으로 빌드하고, ffmpeg 는 이 저장소 소스를 out-of-tree 로 크로스컴파일한다.

## 릴리스

`.github/workflows/release-min-ffmpeg.yml` — 태그 `min-*` push 또는 수동 실행 시:
빌드 → **wine 으로 검증**(컴포넌트 존재 + 실제 BMP 시퀀스 → mp4 스모크) → `ffmpeg.exe` + `.sha256` 를
Release 자산으로 업로드.

```bash
git tag min-8.0-1 && git push origin min-8.0-1   # → Actions 가 빌드·릴리스
```

앱은 `https://github.com/neoqmin/FFmpeg/releases/download/<tag>/ffmpeg.exe` 에서 받는다.

## 라이선스

`--enable-gpl --enable-libx264` 이므로 결과물은 **GPL**. 이 저장소(빌드 스크립트 + ffmpeg/x264 소스)가
대응 소스(corresponding source) 역할을 한다.
