# Deep Reef

A Zeron plugin: a pixel-art coral reef in the deep, behind a new chat and, faded, behind your chats.

Clownfish circle an anemone; a blue tang, bannerfish and a big violet grouper cross at different depths; a school of silver fish, a sea turtle and a manta ray pass; jellyfish rise, glowing. Kelp sways over boulders, branching and brain corals, sea fans, tube sponges and small glowing buds. Light shafts fall from the surface, marine snow sinks, bubbles rise.

## The look

It follows the pixel-art gaussian splats at [splats.cobanov.dev](https://splats.cobanov.dev): forms sculpted in 3D, every surface point lit (a key light from above, occlusion, a grain per material, warm light pooling round what glows) and coloured through a ramp; the picture drawn small; translucent things (light shafts, a jellyfish's glow, the reef's far edge) cut to on/off pixels by a Bayer threshold; every pixel the nearest of a small palette. The scene, its models and its palette are this plugin's own.

There, a model is sampled into tens of thousands of flat splats. A Zeron plugin can't rasterize that many, so here a shader finds each art pixel's surface point directly and shades it the same way; a splat there is about one art pixel, so the result reads the same.

## How it runs

Everything is on the GPU, in `reef_wgsl.luau`, at one texel per art pixel:

- **GROUND**: the still scenery, drawn once (and again when the window changes size) and kept.
- **LIVE**: what moves, drawn each frame over it: 24 frames a second behind a new chat, 15 behind chats.
- **SHOW**: scales the result up, nearest-neighbour.

Zeron's compositor steps the clock, so no script runs per frame.

## Install

In Zeron: **Settings → Plugins → Install…**, then the repository `wingleeio/pixel-reef`.

## Settings

**Settings → Plugins → Deep Reef**:

- **Use as wallpaper**: turns it on behind a new chat (only you can, there).
- **Pixel size**: Fine, Classic or Chunky.
- **Dither**: blends neighbouring palette colours with a checker pattern.
- **Show behind chats** and **Strength**: the faded reef behind a chat's messages.

It asks for `ui.change` (to draw a new chat's background) and `ui.add` (to place the reef behind the transcript), nothing else.

## Files

- `zeron-plugin.json`: the manifest, its settings, and Zeron's signature.
- `init.luau`: where the reef is placed, its settings, the shaders' parameters.
- `reef_wgsl.luau`: the three shader sources, built by `python3 src/build.py`.
- `src/`: what that's built from. `build.py` lays out the reef (rocks, corals, kelp, fish, the palette) as tables; `common.wgsl` is shared by `ground.wgsl` (the still scenery) and `live.wgsl` (what moves); `show.wgsl` is the upscale.
- `zeron.luau`: Zeron's plugin SDK.

## History

This repository first held Pixel Reef, a flat 2D reef. Deep Reef replaced it.
