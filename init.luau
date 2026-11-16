-- Pixel Reef: an underwater scene drawn as pixel art from gaussian splats.
--
-- All of it runs on the GPU (reef_wgsl.luau). A shader pass renders the scene
-- at one texel per art pixel: every creature is a cloud of small anisotropic
-- gaussian splats, each splat's falloff posterized with a Bayer threshold so
-- it reads as a crisp pixel ellipse. A layer shader then blows that texture up
-- nearest-neighbour over the box. The engine steps time on its own clock
-- (`layer_clock`), so no script runs per frame.
--
-- Two places:
--   #new-chat-background  the full reef, as a wallpaper (with parallax)
--   #chat-session         the same reef, slower and faded, behind a chat

local zeron = require("./zeron")("pixel-reef")
local reef = require("./reef_wgsl")

local s_pixel = zeron.setting("pixel")
local s_chats = zeron.setting("chats")
local s_strength = zeron.setting("strength")

-- Screen pixels per art pixel (on a Retina screen, half as many points).
local PIXEL = { fine = 8, classic = 12, chunky = 18 }
local FPS = { wall = 15, chat = 10 }

-- One compiled effect per pixel size and pace, made as first needed.
local shaders: { [string]: any } = {}
local function shader(px: number, mode: string): any
	local key = `{px}:{mode}`
	local s = shaders[key]
	if s == nil then
		s = ui.layer_shader(reef.SHOW, {
			fps = FPS[mode],
			passes = { { name = "reef", shader = reef.SCENE, scale = 1 / px } },
		})
		shaders[key] = s
	end
	return s
end
-- (Compiled off the frame from here, so the default is ready when it shows.)
shader(PIXEL.classic, "wall")
shader(PIXEL.classic, "chat")

local function Reef(mode: string, px: number, params: any): Node
	return ui.div {
		w_full = true,
		h_full = true,
		-- (Shown while the shader compiles. A layer shader filters what its box
		-- paints, so behind a chat it gets a fill too, one nobody can see.)
		bg = if mode == "wall" then "#0f4a70" else "#0a1e3001",
		layer_shader = shader(px, mode),
		layer_clock = true,
		layer_params = params,
		pointer_events = "none",
		aria_hidden = true,
	}
end

local function num(v: any): number
	return if type(v) == "number" then v else 0.5
end

-- Behind a new chat: the full reef, its layers following the pointer.
zeron.place {
	at = "#new-chat-background",
	fill = true,
	replace = function(): Node
		local pointer = zeron.live("pointer")
		return ui.presence(function(): string
			return s_pixel:get() or "classic"
		end, function(key: string): Node
			return Reef("wall", PIXEL[key] or PIXEL.classic, function(): { any }
				local p = if pointer then pointer() else nil
				local x = if type(p) == "table" then num(p.x) else 0.5
				local y = if type(p) == "table" then num(p.y) else 0.5
				return { { x, y, 0, 0 }, { 1, 1, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
			end)
		end, { w_full = true, h_full = true })
	end,
}

-- Behind a chat: the same reef, slower and faded so the messages read. It's
-- placed by the transcript: the column holding it is a positioned box (the
-- area messages scroll in), which the reef fills.
local STRENGTH = {
	dark = { subtle = 0.3, medium = 0.45, vivid = 0.6 },
	light = { subtle = 0.16, medium = 0.24, vivid = 0.34 },
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
				return `{look}|{s_strength:get() or "subtle"}|{s_pixel:get() or "classic"}`
			end, function(key: string): Node
				if key == "off" then
					return ui.div {}
				end
				local look, strength, pixel = string.match(key, "^(.-)|(.-)|(.*)$")
				local levels = STRENGTH[look or "dark"] or STRENGTH.dark
				local alpha = levels[strength or "subtle"] or levels.subtle
				return Reef("chat", PIXEL[pixel or "classic"] or PIXEL.classic, {
					{ 0.5, 0.5, 0, 0 },
					{ alpha, 0.85, 0, 0 },
					{ 0, 0, 0, 0 },
					{ 0, 0, 0, 0 },
				})
			end, { w_full = true, h_full = true }),
		}
	end,
}
