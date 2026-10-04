# WiVRn + DXVK Gaze-Driven VRS

Experimental gaze-driven variable rate shading for VRChat over WiVRn.

This repository packages the **working changes from the test**, without modifying or “fixing” the implementation. The two patch files are the existing DXVK and WiVRn changes supplied for this project;
This was tested on Arch linux, with the Pico 4 Pro headset.

## What it does

WiVRn exports the per-eye fovea center into `/dev/shm/wivrn_gaze`. Patched DXVK reads that shared-memory state on the Windows side and builds a Vulkan fragment-shading-rate attachment around the gaze point.

For VRChat, the important discovery was that applying VRS to every similarly sized rendering pass produced multiple independent foveation spots. The tested working configuration restricts VRS to the `VK_FORMAT_R16G16B16A16_SFLOAT` scene pass (`VkFormat` value `97`) and excludes depth-only passes. The scene pass also needs a vertical coordinate flip (`DXVK_GAZE_FLIP_Y=1`).

The tested command was:

```text
DXVK_GAZE_VRS=1 DXVK_GAZE_DEBUG=1 DXVK_GAZE_DOT=1 DXVK_GAZE_FMT=97 DXVK_GAZE_FLIP_Y=1 DXVK_GAZE_R1=0.06 DXVK_GAZE_R2=0.12 DXVK_GAZE_COARSE=6
```

For normal use, leave the debug variables off:

```text
DXVK_GAZE_VRS=1 DXVK_GAZE_FMT=97 DXVK_GAZE_FLIP_Y=1 DXVK_GAZE_R1=0.06 DXVK_GAZE_R2=0.12 DXVK_GAZE_COARSE=6
```

See [`config/vrchat.env`](config/vrchat.env).

## Requirements

### Runtime

You need:

- WiVRn server and its matching headset/client version.
- A Vulkan GPU/driver that exposes `VK_KHR_fragment_shading_rate` with attachment fragment shading rate support.
- A Wine/Proton setup that uses the patched DXVK `d3d11.dll` and `dxgi.dll`.
- VRChat configured to run through the WiVRn OpenXR/Steam compatibility stack.

WiVRn's current documentation recommends native distribution packages where available, and notes that Steam/OpenVR compatibility also needs xrizer or OpenComposite.

## Exact upstream revisions used by this experiment

**WiVRn:**

```text
v26.9
bbc6e4cc36c355fa6180980abd231673dc15115d
```

This repository is intentionally pinned to the latest matching WiVRn release rather than an arbitrary `master` checkout. GitHub currently lists `v26.9` as the latest release, at commit `bbc6e4c`.

CI verifies this pin: when `wivrn_ref=v26.9` is passed, the job fails if the resolved commit is not `bbc6e4cc36c355fa6180980abd231673dc15115d`.

**DXVK:**

```text
d30be2ba
```

The working build was configured with:

```text
-Dbuildtype=release -Denable_d3d8=false -Denable_d3d9=false -Denable_d3d10=false --cross-file=build-win64.txt
```

The patch records the exact parent blob hashes for the files it changes. Set `DXVK_SOURCE_DIR` to the same working DXVK checkout (or its exact base revision `d30be2ba`) when applying/building.

## Install DXVK into Proton

After building:

```bash
./scripts/install-dxvk.sh "/path/to/your/Proton"
```

The installer searches the Proton tree for a DXVK directory containing both `d3d11.dll` and `dxgi.dll`, creates a timestamped backup, and replaces only those two files.

To restore a backup:

```bash
PROTON_DIR="/path/to/your/Proton" ./scripts/uninstall-dxvk.sh "/path/to/backup"
```

A Proton update can replace the DLLs, so reinstall the two patched files after changing Proton versions.

## Install WiVRn server

The CI build (and the matching GitHub Release) produces a patched `wivrn-server` binary, and `wivrn-dashboard` when the dashboard target is built. These come from the pinned `v26.9` source with `patches/wivrn-gaze-export.patch` applied — that patch is what writes `/dev/shm/wivrn_gaze` for the patched DXVK to read.

Download `wivrn-server.zip` from the run's **Artifacts** section or from
the Releases page, then unpack it somewhere:

```bash
unzip ./wivrn-server.zip
install -Dm755 wivrn-server/wivrn-server    "$HOME/.local/bin/wivrn-server"
install -Dm755 wivrn-server/wivrn-dashboard "$HOME/.local/bin/wivrn-dashboard"
```

### Running

The server has two parts:

- `wivrn-server` — the PC-side server. It creates the shared-memory gaze file at `/dev/shm/wivrn_gaze` and handles the streaming session.
- `wivrn-dashboard` — the GUI used to pair/connect the headset client and to start/stop the server.

Typical use:

```bash
# start the server directly (it will listen for the headset client):
wivrn-server

# or launch the GUI and connect from there:
wivrn-dashboard
```

Running `wivrn-server` under a user systemd service is the common setup on distros that ship WiVRn as a package; if you already have such a unit, replace only the `ExecStart` binary with the patched one from the archive rather than inventing a new unit.

### Matching the headset client

The headset client and PC server **must be on the same WiVRn version**. This repo builds the server side only. Install the official WiVRn client for `v26.9` on the headset:

- Non-Meta headsets: install the `v26.9` APK from WiVRn's releases.
- Meta Quest: use the matching Meta Store client when available.

Do **not** mix the CI-built `v26.9` server with a newer or older headset client.

### Verifying the gaze file

Once the server is running and a session is active, the patched server writes per-eye fovea centers to `/dev/shm/wivrn_gaze`. On the Linux side you can confirm it exists while a session is up:

```bash
ls -l /dev/shm/wivrn_gaze
```

Inside the Wine/Proton prefix the same file is visible as `Z:\dev\shm\wivrn_gaze`, which is the path the patched DXVK reads (overridable with `DXVK_GAZE_FILE`).

## Build

The upstream DXVK project documents Meson + mingw-w64 requirements and provides `package-release.sh` for release builds.

For the known working build configuration:

```bash
export DXVK_SOURCE_DIR=/path/to/the/working/dxvk
./scripts/apply-dxvk.sh
./scripts/build-dxvk.sh
```

For WiVRn, start from the exact pinned release:

```bash
git clone --branch v26.9 --depth 1 https://github.com/WiVRn/WiVRn.git WiVRn-v26.9
export WIVRN_SOURCE_DIR="$PWD/WiVRn-v26.9"
./scripts/build-wivrn.sh
```

The script verifies that the checkout is exactly `v26.9` / `bbc6e4cc36c355fa6180980abd231673dc15115d` before applying the existing gaze-export change. It builds the PC server/dashboard only; **it does not build the Android/headset client**. That is deliberate because WiVRn requires the headset client and PC server to use the same version.

### Build in CI

The `.github/workflows/build-dxvk.yml` workflow builds both projects on GitHub-hosted runners and uploads them as artifacts.

Trigger it from **Actions → Build DXVK gaze-VRS + WiVRn → Run workflow**.

| Input         | Default                                 | Notes |
|---------------|-----------------------------------------|-------|
| `dxvk_ref`    | `d30be2ba`                              | Must match the base revision `dxvk-gaze-vrs.patch` was made against |
| `wivrn_ref`   | `v26.9`                                 | Pinned release; CI verifies it resolves to `bbc6e4c` |
| `dxvk_repo`   | `https://github.com/doitsujin/dxvk.git` | Override to build from a fork |
| `wivrn_repo`  | `https://github.com/WiVRn/WiVRn.git`    | Override to build from a fork |
| `release_tag` | *(empty)*                               | If set, also publish a GitHub Release with this tag |

Artifacts:

- **`dxvk-gaze-vrs`** — patched `d3d11.dll` and `dxgi.dll` (MinGW, Windows).
- **`wivrn-server`** — patched `wivrn-server` and `wivrn-dashboard` (Linux).

The workflow does **not** build the Android/headset client, matching the local `scripts/build-wivrn.sh`. Install the official WiVRn client for `v26.9` alongside the CI-built server.

### Releases

Set `release_tag` when triggering the workflow (or push a `v*` tag) to publish a GitHub Release. The release attaches:

- `dxvk-gaze-vrs.zip` — the patched Windows DLLs.
- `wivrn-server.zip` — the patched Linux server and dashboard.

This is the easiest way for other people to grab prebuilt binaries without digging through Actions artifacts. If the WiVRn job fails but DXVK succeeds, the release still publishes with the DXVK zip only.

## VRChat launch configuration

Enable the feature in the environment used to launch VRChat. The safe starting configuration is the one under `config/vrchat.env`.

For a debug run, add:

```text
DXVK_GAZE_DEBUG=1 DXVK_GAZE_DOT=1
```

The dot is only a diagnostic overlay. Turn it off for normal use.

### Why `FMT=97` and `FLIP_Y=1` matter

VRChat was observed to issue several passes of the same general size. The working test found RGBA16F scene passes (`fmt=97`), RGBA8 sRGB passes (`fmt=43`), and depth-only passes (`fmt=0`). Applying gaze VRS to all of them produced multiple visible foveation locations and could make the result glitchy. Restricting the experiment to `fmt=97` leaves the tested scene pass as the VRS target.

The vertical orientation issue was resolved by flipping the Y coordinate for that scene pass. In the working implementation this is controlled by `DXVK_GAZE_FLIP_Y=1`.

## Debugging

Useful variables:

| Variable | Purpose |
|---|---|
| `DXVK_GAZE_VRS=1` | Enable gaze VRS when the Vulkan feature is available |
| `DXVK_GAZE_FMT=97` | Restrict VRS to the tested VRChat RGBA16F scene pass |
| `DXVK_GAZE_FLIP_Y=1` | Flip scene-pass Y orientation |
| `DXVK_GAZE_R1` | Inner radius of the sharp region |
| `DXVK_GAZE_R2` | Start of the outer coarse region |
| `DXVK_GAZE_COARSE` | Outer shading-rate code; `6` is the tested `2x4` setting |
| `DXVK_GAZE_DEBUG=1` | Enable pass/gaze diagnostics |
| `DXVK_GAZE_DOT=1` | Draw diagnostic gaze dots |
| `DXVK_GAZE_DOT_RADIUS` | Diagnostic dot half-size |
| `DXVK_GAZE_GAIN_Y` | Scale vertical gaze offset around screen center |
| `DXVK_GAZE_SWAP_EYES=1` | Swap per-eye gaze data |
| `DXVK_GAZE_FLIPX_L/R` | Force per-eye X flip (`0` or `1`) |
| `DXVK_GAZE_FLIPY_L/R` | Force per-eye Y flip (`0` or `1`) |
| `DXVK_GAZE_FAKE=x/y/circle/fixed/grid` | Synthetic gaze/debug modes |
| `DXVK_GAZE_FIXED_Y` | Y value used by `FAKE=fixed` |
| `DXVK_GAZE_SIZE=WxH` | Force a framebuffer size candidate |
| `DXVK_GAZE_SAMPLES` | Restrict to one sample count |
| `DXVK_GAZE_FILE` | Override the Wine-visible gaze file path |

For a debug VRChat run, the useful log shape(when PROTON_LOG=1 is set) is:

```bash
grep -a "passes in last" -A8 ~/steam-438100.log | tail -24
```

## Architecture

```text
Eye tracking / VRChat
        |
        v
      WiVRn
        |
        | foveation.cpp
        | /dev/shm/wivrn_gaze
        v
  shared-memory gaze state
        |
        | Wine path: Z:\\dev\\shm\\wivrn_gaze
        v
       DXVK
        |
        | DxvkGazeVrs
        | Vulkan VK_KHR_fragment_shading_rate
        v
  per-pass shading-rate image
        |
        v
   VRChat scene pass
```

The shared-memory layout is defined inside the existing DXVK implementation and is intended to match the producer in WiVRn. This repository deliberately preserves that implementation as supplied rather than introducing a new compatibility layer.

## Current limitations

This is experimental code, not a finished general-purpose foveated-rendering implementation. The pass selection defaults documented here are based on the tested VRChat rendering path, and other applications or Proton/WiVRn configurations may need different pass filters or coordinate transforms.

The repository does not claim that `fmt=97` or `FLIP_Y=1` are universal VRChat requirements; they are the working values from this experiment.

CI is experimental in the same way the code is. The WiVRn dependency list in the workflow is a best-effort Ubuntu 24.04 baseline; the exact `qml6-module-*` package names and the OpenXR/Vulkan header versions the distro provides may need adjusting for a given WiVRn revision.

### Keeping WiVRn matched

When WiVRn releases a new version, update `versions.env`, `UPSTREAM.md`, and the documented client version together with the new release/commit. Do not mix a newer server with an older headset client. The official WiVRn documentation explicitly warns that the VR client and PC server must be on the same version.

## WiVRn client: use the matching official build

This project does **not** include or build the Android headset client. Install the official WiVRn headset client corresponding to the pinned server release (`v26.9`). WiVRn's own README says the headset client and PC server need to be on the same version.

For non-Meta headsets, WiVRn's releases provide the corresponding APK; Meta Quest users should use the matching Meta Store client when available. The PC build here is only the server/dashboard side.