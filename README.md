# WiVRn + DXVK Gaze-Driven VRS

Experimental gaze-driven variable rate shading for VRChat over WiVRn(also works for any DXVK application).
Tested on Arch with a Pico 4 Pro.

WiVRn exports the per-eye fovea center to `/dev/shm/wivrn_gaze`. Patched
DXVK reads that shared memory and builds a Vulkan fragment-shading-rate
attachment around the gaze point.

VRChat issues several passes of similar size, so VRS has to be restricted
to the RGBA16F scene pass (`fmt=97`) with a Y flip - otherwise you get
multiple foveation spots. These are the tested values, not universal
requirements.

> [!WARNING]
> Experimental, use at your own risk. This is an unofficial modification, not endorsed by or affiliated with VRChat, WiVRn or DXVK. It replaces `d3d11.dll` and `dxgi.dll` in your Proton install, and VRChat's rules or anti-cheat may treat modified clients differently. I haven't verified how. Tested only on an RTX 3060 Ti with a Pico 4 Pro.

## Install

**DXVK** - replaces `d3d11.dll` and `dxgi.dll` in a Proton install:  
**! Replaces files in your Proton install (originals are backed up to `.backup/`).**

    ./scripts/install-dxvk.sh --dxvk-from ./dxvk-gaze-vrs.zip "/path/to/Proton"  


Omit `--dxvk-from` to use a local build from `dist/dxvk`. The installer
backs up the originals to `.backup/` and only touches those two files. A
Proton update overwrites them - reinstall afterward.

**WiVRn server** - patched v26.9, from the CI release:

    unzip wivrn-server.zip
    sudo cp -a usr/. /usr/

Installs `/usr/bin/wivrn-server` and the OpenXR runtime manifest under
`/usr/share/openxr/1/`. CI builds the server only; a local build with
`scripts/build-wivrn.sh` also produces `wivrn-dashboard` (a GUI).

WiVRn headset client and server must be the same version. Grab the
matching `v26.9` client from WiVRn's releases.

## Run VRChat

    DXVK_GAZE_VRS=1 DXVK_GAZE_FMT=97 DXVK_GAZE_FLIP_Y=1 DXVK_GAZE_R1=0.4 DXVK_GAZE_R2=0.48 DXVK_GAZE_COARSE=5

Add `DXVK_GAZE_DEBUG=1 DXVK_GAZE_DOT=1` to draw the gaze dots. See
[`config/vrchat.env`](config/vrchat.env).

Verify the shared-memory file exists while a session is up:

    ls -l /dev/shm/wivrn_gaze

## Env vars

| Variable | Purpose |
|---|---|
| `DXVK_GAZE_VRS=1` | Enable gaze VRS |
| `DXVK_GAZE_FMT=97` | Restrict to the RGBA16F scene pass |
| `DXVK_GAZE_FLIP_Y=1` | Flip scene-pass Y |
| `DXVK_GAZE_R1` / `R2` | Inner / outer radius of the sharp region |
| `DXVK_GAZE_COARSE` | Outer shading-rate code (`6` = 2x4) |
| `DXVK_GAZE_DEBUG=1` | Pass/gaze diagnostics |
| `DXVK_GAZE_DOT=1` | Draw diagnostic gaze dots |
| `DXVK_GAZE_SWAP_EYES=1` | Swap per-eye gaze data |
| `DXVK_GAZE_GAIN_Y` | Scale vertical gaze offset around center |
| `DXVK_GAZE_FLIPX_L/R`, `FLIPY_L/R` | Force per-eye X/Y flip |
| `DXVK_GAZE_FAKE=x/y/circle/fixed/grid` | Synthetic gaze modes |
| `DXVK_GAZE_SIZE=WxH`, `SAMPLES` | Force size / sample count |
| `DXVK_GAZE_FILE` | Override the gaze file path |

For a debug run with `PROTON_LOG=1`:

    grep -a "passes in last" -A8 ~/steam-438100.log | tail -24

### What R1 and R2 mean

`DXVK_GAZE_R1` and `R2` are radii, not screen fractions, and `d` is
normalized by the shorter eye dimension. So for a square eye:

| `R1` | full-res area |
|---|---|
| 0.25 | ~20% |
| 0.40 | ~50% |
| 0.49 | ~75% |
| 0.50 | ~78% |
| 0.56 | ~100% |

`R1` is where shading starts to drop; `R2` is where it hits `COARSE`.
Below `R1` is 1×1, between `R1` and `R2` is 2×2, beyond `R2` is whatever
`DXVK_GAZE_COARSE` says. Keep `R2 > R1`, or the transition band
disappears. They're read at device creation, so a VRChat restart is
needed to change them.

To pick `R` for a target area percentage:

```
R = sqrt(area / pi)
```

So 50% → `sqrt(0.50 / 3.14159)` → `0.40`. 75% → `0.49`. 90% → `0.54`.
This works up to ~78% (the inscribed circle); past that, the corners of
the eye fall outside the circle and stay coarse no matter how large `R`
gets.

## Build

Both projects build from pinned revisions. Defaults live under `.work/`
in the repo; override with env vars.

    # DXVK d30be2ba -> dist/dxvk
    DXVK_SOURCE_DIR=/path/to/dxvk ./scripts/build-dxvk.sh

    # WiVRn v26.9 -> .work/WiVRn/build-gaze-vrs
    WIVRN_SOURCE_DIR=/path/to/WiVRn ./scripts/build-wivrn.sh

`build-dxvk.sh` and `build-wivrn.sh` call the matching `apply-*.sh`
themselves - don't run those separately or the patch gets applied twice.
`build-wivrn.sh` refuses to build unless the checkout is exactly the
pinned commit; `versions.env` holds the pin.

The local WiVRn script builds the server, dashboard, and `wivrnctl`, but
not the Android/headset client.

### CI

`.github/workflows/build-dxvk.yml` builds both from pinned refs and
uploads artifacts. Trigger from **Actions → Run workflow**. Set
`release_tag` to publish a GitHub Release.

CI's WiVRn job builds the **server only** (no dashboard) and runs
`cmake --install` into a staging tree - that's why the install step is
`cp -a usr/. /usr/` rather than copying binaries.

## Architecture

    Eye tracking
          |
          v
        WiVRn  --- /dev/shm/wivrn_gaze ---> DXVK (via Wine path)
                                                 |
                                                 v
                                  VK_KHR_fragment_shading_rate
                                                 |
                                                 v
                                          VRChat scene pass

## Notes

- The two patch files are the supplied working changes, unmodified.
- Everything here is experimental; `fmt=97` and `FLIP_Y=1` are just the
  values that worked for this test.
- Revisions: DXVK `d30be2ba`, WiVRn `v26.9` / `bbc6e4c` (see
  `versions.env`). The DXVK patch records its parent blob hashes, so the
  DXVK ref must match exactly.

## Demo with overexadurated values and gaze dot enabled
[Google drive link](https://drive.google.com/file/d/1OabrqSbzjEp96AFs6StbJrUAcHWSyMiQ/view?usp=sharing)
