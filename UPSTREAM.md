# Upstream provenance

## WiVRn

Repository: https://github.com/WiVRn/WiVRn

This project is pinned to the **same WiVRn release used by the current headset client**:

```text
release: v26.9
commit:  bbc6e4cc36c355fa6180980abd231673dc15115d
```

As of October 4, 2026, GitHub lists `v26.9` as the latest WiVRn release, and that tag points to the `bbc6e4c` commit used by this experiment.

**Important:** WiVRn requires the VR client and PC server to use the same version. This repository therefore refuses to build the WiVRn side from a different commit.

The WiVRn build in this repository is **PC/server-only**. `WIVRN_BUILD_CLIENT=OFF` is intentional: users should use the official matching headset client rather than being asked to build the Android app. WiVRn's own build system supports a server-only configuration.

The local working checkout also contained a `changes.patch` alongside the edited `server/compositor/foveation.cpp`; the repository's WiVRn patch is the same existing change supplied for this project.

## DXVK

Repository: https://github.com/doitsujin/dxvk

The supplied patch was generated against the user's working tree. The exact `git rev-parse HEAD` of that tree was not included in the supplied material, so this repository does not invent one.

The working DXVK build configuration was:

```text
-Dbuildtype=release -Denable_d3d8=false -Denable_d3d9=false -Denable_d3d10=false --cross-file=build-win64.txt
```

The patch contains the parent blob hashes for the modified DXVK files.
