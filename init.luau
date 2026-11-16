-- Deep Reef: a pixel-art coral reef in the deep, behind a new chat and,
-- faded, behind your chats.
--
-- The whole scene runs on the GPU (reef_wgsl.luau), at one texel per art
-- pixel. The still scenery (sand, boulders, corals) is a pass drawn once and
-- kept; what moves (fish, a turtle, a manta, jellyfish, kelp, light shafts,
-- snow, bubbles) is a pass drawn each frame over it; a layer shader scales
-- the result up nearest-neighbour. The engine steps time on its own clock
-- (`layer_clock`), so no script runs per frame.
--
-- Two places:
--   #new-chat-background  the reef framed round the message box, as a wallpaper
--   #transcript           the same reef, slower and faded, behind a chat

local zeron = require("./zeron")("deep-reef")
local reef = require("./reef_wgsl")

local s_pixel = zeron.setting("pixel")
local s_dither = zeron.setting("dither")
local s_chats = zeron.setting("chats")
local s_strength = zeron.setting("strength")

-- Screen pixels per art pixel (on a Retina screen, half as many points).
local PIXEL = { fine = 8, classic = 10, chunky = 14 }
local FPS = { wall = 24, chat = 15 }
-- How strongly neighbouring palette colours are dithered, when that's on.
local DITHER = 0.9

-- One compiled effect per pixel size and pace, made as first needed.
local shaders: { [string]: any } = {}
local function shader(px: number, mode: string): any
	local key = `{px}:{mode}`
	local s = shaders[key]
	if s == nil then
		s = ui.layer_shader(reef.SHOW, {
			fps = FPS[mode],
			passes = {
				-- The still scenery: light, material, depth and warm light per
				-- art pixel (past 0 to 1, so in floats), drawn once.
				{ name = "ground", shader = reef.GROUND, scale = 1 / px, format = "rgba16float", once = true },
				-- What moves, over it, each frame.
				{ name = "reef", shader = reef.LIVE, scale = 1 / px },
			},
		})
		shaders[key] = s
	end
	return s
end
-- (Compiled off the frame from here, so the default is ready when it shows.)
shader(PIXEL.classic, "wall")
shader(PIXEL.classic, "chat")

-- params: { -, -, dither, speed }, { alpha, brightness, zoom, lift },
-- { open water's alpha, how muted, -, - }.
local function Scene(mode: string, px: number, params: { any }): Node
	return ui.div {
		w_full = true,
		h_full = true,
		-- (Shown while the shaders compile. A layer shader filters what its box
		-- paints, so behind a chat it gets a fill too, one nobody can see.)
		bg = if mode == "wall" then "#0a1730" else "#0a173001",
		layer_shader = shader(px, mode),
		layer_clock = true,
		layer_params = params,
		pointer_events = "none",
		aria_hidden = true,
	}
end

-- Behind a new chat: the camera tipped down a little, so the reef stands
-- round the message box and over Zeron's fade at the foot.
zeron.place {
	at = "#new-chat-background",
	fill = true,
	replace = function(): Node
		return ui.presence(function(): string
			return `{s_pixel:get() or "classic"}|{if s_dither:get() == true then "1" else "0"}`
		end, function(key: string): Node
			local pixel, dither = string.match(key, "^(.-)|(.*)$")
			return Scene("wall", PIXEL[pixel or "classic"] or PIXEL.classic, {
				{ 0, 0, if dither == "1" then DITHER else 0, 1 },
				{ 1, 1, 0.95, -0.42 },
				-- (Muted a little, as the chats' is by its fade.)
				{ 1, 0.2, 0, 0 },
				{ 0, 0, 0, 0 },
			})
		end, { w_full = true, h_full = true })
	end,
}

-- Behind a chat: the same reef, slower and faded so the messages read. It's
-- placed by the transcript: the column holding it is a positioned box (the
-- area messages scroll in).
local STRENGTH = {
	dark = { subtle = 0.4, medium = 0.55, vivid = 0.75 },
	light = { subtle = 0.2, medium = 0.3, vivid = 0.45 },
}

zeron.place {
	at = "#transcript",
	before = function(): Node
		local appearance = zeron.live("appearance")
		return ui.div {
			absolute = true,
			left = 0,
			right = 0,
			top = 0,
			-- (The transcript's column stops at the composer's footer line,
			-- 40 points over the page's foot: Zeron's chat/dock page_pad.
			-- The reef runs on to the foot.)
			bottom = -40,
			pointer_events = "none",
			ui.presence(function(): string
				if s_chats:get() == false then
					return "off"
				end
				local look = if appearance and appearance() == "light" then "light" else "dark"
				local dither = if s_dither:get() == true then "1" else "0"
				return `{look}|{s_strength:get() or "subtle"}|{s_pixel:get() or "classic"}|{dither}`
			end, function(key: string): Node
				if key == "off" then
					return ui.div {}
				end
				local look, strength, pixel, dither = string.match(key, "^(.-)|(.-)|(.-)|(.*)$")
				local levels = STRENGTH[look or "dark"] or STRENGTH.dark
				local alpha = levels[strength or "subtle"] or levels.subtle
				return Scene("chat", PIXEL[pixel or "classic"] or PIXEL.classic, {
					{ 0, 0, if dither == "1" then DITHER else 0, 0.8 },
					{ alpha, 1, 1, 0 },
					{ 1, 0, 0, 0 },
					{ 0, 0, 0, 0 },
				})
			end, { w_full = true, h_full = true }),
		}
	end,
}
