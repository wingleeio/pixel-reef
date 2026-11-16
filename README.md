# Pixel Reef

A Zeron plugin: an animated, pixel-art underwater reef drawn from gaussian splats, behind a new chat and, faded, behind your chats.

Clownfish, tangs, a butterflyfish, a wrasse and a grouper; a school of silver fish; a sea turtle; a manta ray gliding overhead; pulsing jellyfish; swaying kelp, coral and anemones; light rays, caustics, rising bubbles and marine snow.

## How it's drawn

Everything runs on the GPU, in `reef_wgsl.luau`:

- **Splats.** Every creature is a cloud of small anisotropic gaussian splats (rows of scale-like splats along a fish's outline, fanned tail rays, shell plates, segmented manta wings, a jellyfish's dome), composited back to front.
- **Pixel art.** The scene is rendered by a shader pass at one texel per art pixel. Each splat's falloff is posterized to three steps with a 4×4 Bayer threshold, so splats read as crisp pixel ellipses with dithered rims, lit from above. The water is banded by depth, dithered only where bands meet, and the frame is rounded to a small palette. A layer shader then scales it up nearest-neighbour.
- **Underwater.** Far creatures fade into the blue and lose their reds, rows of pixels waver like light bending through water, and on the new chat page the layers shift with the pointer for parallax.
- **Cheap.** Zeron's compositor steps the clock (`layer_clock`), so no script runs per frame; the scene costs well under a millisecond of GPU per frame at 15 fps (10 fps behind chats), whatever the window size.

## Install

In Zeron: **Settings → Plugins → Install…**, then the repository `wingleeio/pixel-reef`.

Then on **Settings → Plugins → Pixel Reef**:

- **Use as wallpaper**: turns it on behind a new chat (only you can, there).
- **Pixel size**: Fine, Classic or Chunky.
- **Show behind chats** and **Strength**: the faded reef behind a chat's messages (Subtle, Medium or Vivid).

It asks for `ui.change` (to draw a new chat's background) and `ui.add` (to place the reef behind the transcript), nothing else.

## Files

- `zeron-plugin.json`: the manifest, its settings, and Zeron's signature.
- `init.luau`: where the reef is placed, its settings, the shader's parameters.
- `reef_wgsl.luau`: the scene (`SCENE`, the pass) and the upscale (`SHOW`), in WGSL.
- `zeron.luau`: Zeron's plugin SDK.
