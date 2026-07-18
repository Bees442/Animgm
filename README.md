# animgm

A 2D frame-by-frame animation program built in **GameMaker**

## Features

- **Project Manager** — welcome screen with recent projects, thumbnails, and a
  New Project dialog with resolution/format presets (1080p, 4K, Square, Story…).
- **Drawing tools** — brush (with a Photoshop-style stroke stabilizer and
  anti-aliased edges), line, shapes (rect/ellipse/polygon/star…), eraser,
  paint bucket (flood fill), eyedropper, hand, zoom.
- **Selection & transform** — rectangular marquee with move / resize / rotate
  handles, plus editable X/Y/W/H/Rotation fields in the properties panel.
  Cut / Copy / Paste / Delete.
- **Timeline** — layers, keyframes (Flash-style spans), playback, onion skin,
  scrubbing, adjustable frame count and FPS.
- **Layers** — add / duplicate / reorder / rename / delete (right-click menu),
  visibility, lock, per-layer opacity.
- **Custom window chrome** — borderless window with a custom title bar
  (minimize / maximize / close), smooth maximize animation, and an
  unsaved-changes guard on close / open / new.
- **Image import** — via File → Import or (WIP) drag-and-drop; each image lands
  on its own new layer.
- **Save / Load** — compact binary `.anst` format (deflate-compressed raster
  frames, cropped to their bounding box).
- **MP4 export** — each frame is rendered straight to a surface and encoded
  in-process (OpenH264 + minimp4, see below); no external ffmpeg.exe.

## Requirements

- **GameMaker** IDE, runtime **2024.1400.5.1065** (LTS 2024.14) or compatible.
- **Windows** target (the native extension and window handling are Windows-only).
- **`openh264-2.6.0-win64.dll`** next to the game executable, for MP4 export
  (Cisco's prebuilt H.264 encoder — BSD-licensed, ~1 MB; see
  `extensions/ext_ffmpeg/openh264-2.6.0-win64.dll`).

## Building

Open `animgm.yyp` in the GameMaker IDE and run the **Windows** target.

## Native extension (`ext_ffmpeg`)

A C++ DLL under `extensions/ext_ffmpeg/` provides what plain GML cannot:

- `mp4enc_open` / `mp4enc_add_frame` / `mp4enc_close` / `mp4enc_last_error` —
  MP4 export. Loads `openh264-2.6.0-win64.dll` at runtime (dynamically, via
  `LoadLibrary` — no import `.lib` is shipped for it), converts each RGBA8
  frame to I420, encodes it, and muxes the H.264 stream into an MP4 with
  `minimp4` (single-header library, `thirdparty/minimp4/`). Headers for the
  OpenH264 API live in `thirdparty/openh264/`.
- `dnd_enable` / `dnd_count` / `dnd_poll` — drag-and-drop, since GML has no
  built-in support for it (and `execute_program`/`execute_shell`, which older
  GameMaker versions used for launching external processes, were dropped in
  GameMaker Studio 2+ for security/store-policy reasons — one more reason
  this now runs in-process instead of shelling out to ffmpeg).

GameMaker caches extension DLLs — do a clean rebuild (MSVC) after editing
`ffmpeg_ext.cpp` if changes don't take.

## File format (`.anst`)

Binary. Header (magic `ANS2` + version), then project metadata, layers, and
per-keyframe raster blobs. Frames are stored as the deflate-compressed ARGB of
their non-transparent bounding box, so a mostly-empty drawing stays tiny.
Older versions (`ANS1` JSON header, uncompressed `v1`/`v2`) still load.

## Known limitations / TODO

- Drag-and-drop file import is implemented but flaky (GameMaker DLL caching).
- MP4 export needs `openh264-2.6.0-win64.dll` next to the executable.
- Windows-only (native extension + custom window chrome).
- Imported images are flattened into the raster (not re-editable objects).

## Planned

- **Export to more formats** — PNG sequence, GIF, WebM (currently MP4 only).
- **Audio import** — load a soundtrack and mux it into MP4 exports.
- **Auto-select (magic wand)** — select a region by colour similarity, not
  just the rectangular marquee.
- **Skeletal animation** — bones, hierarchy, and pixel-to-bone binding as an
  alternative to raster-only frames.
