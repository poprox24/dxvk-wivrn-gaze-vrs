# Architecture notes

## Data path

WiVRn calculates its normal foveation parameters in `foveation::compute_params()`. The supplied change additionally converts each eye's foveation center to normalized display coordinates and exports them to a shared-memory object at `/dev/shm/wivrn_gaze`.

The DXVK side maps the same data through Wine as `Z:\dev\shm\wivrn_gaze`, validates the sequence number and magic value, and reads both eye centers. It then constructs a fixed-size `VK_FORMAT_R8_UINT` fragment-shading-rate attachment and uploads tile rates only when the relevant tile geometry or gaze tile position changes.

## VRChat pass selection

The working VRChat run showed multiple rendering passes. The supplied DXVK code therefore includes three filters relevant to stability:

1. Depth-only passes (`VK_FORMAT_UNDEFINED`) are rejected.
2. `DXVK_GAZE_SAMPLES` may restrict sample count.
3. `DXVK_GAZE_FMT` may restrict Vulkan color format.

For the known-good VRChat test, `DXVK_GAZE_FMT=97` targets the RGBA16F scene pass.

## Vertical coordinate handling

The implementation converts WiVRn display coordinates into framebuffer coordinates and can invert Y with `DXVK_GAZE_FLIP_Y`. The tested VRChat scene pass required that inversion for the gaze location to track vertical eye movement correctly.
