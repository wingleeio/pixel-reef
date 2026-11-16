-- The reef, as one WGSL fill shader: every art pixel evaluates the scene at
-- its centre. Creatures are clouds of small anisotropic gaussian splats,
-- composited back to front, each splat's falloff posterized to three steps
-- with a Bayer threshold (so splats read as crisp pixel ellipses with
-- dithered rims), lit from above, hazed by depth; then the whole frame is
-- reduced to a small palette with ordered dithering.
--
-- Two sources: SCENE is a pass drawn at one texel per art pixel (a small
-- texture, so the scene runs once per art pixel, not once per screen pixel);
-- SHOW is the layer shader that blows it up, nearest-neighbour, over the box.
--
-- params[0] = { pointer x, pointer y, -, - }
-- params[1] = { alpha, brightness, -, - }
local M = {}
M.SCENE = [==[
var<private> g_q: vec2<f32>;
var<private> g_ql: vec2<f32>;
var<private> g_th: f32;
var<private> g_t: f32;
var<private> g_a: f32;
var<private> g_ptr: vec2<f32>;
var<private> g_col: vec3<f32>;
var<private> g_cs: f32;
var<private> g_hz: f32;

fn r_h(p: vec2<f32>) -> f32 {
	return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn r_bayer(c: vec2<f32>) -> f32 {
	var m = array<f32, 16>(0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	let x = u32(abs(c.x)) & 3u;
	let y = u32(abs(c.y)) & 3u;
	return (m[y * 4u + x] + 0.5) / 16.0;
}

fn r_water(y0: f32) -> vec3<f32> {
	let y = clamp(y0, 0.0, 1.0);
	let c0 = vec3<f32>(0.40, 0.80, 0.86);
	let c1 = vec3<f32>(0.20, 0.64, 0.78);
	let c2 = vec3<f32>(0.09, 0.45, 0.67);
	let c3 = vec3<f32>(0.05, 0.28, 0.50);
	let c4 = vec3<f32>(0.03, 0.16, 0.34);
	let c5 = vec3<f32>(0.016, 0.08, 0.20);
	if (y < 0.12) { return mix(c0, c1, y / 0.12); }
	if (y < 0.3) { return mix(c1, c2, (y - 0.12) / 0.18); }
	if (y < 0.55) { return mix(c2, c3, (y - 0.3) / 0.25); }
	if (y < 0.8) { return mix(c3, c4, (y - 0.55) / 0.25); }
	return mix(c4, c5, (y - 0.8) / 0.2);
}

// Seen through water: reds absorbed with depth, far things fade to blue.
fn r_hz(col: vec3<f32>, y: f32) -> vec3<f32> {
	let ab = vec3<f32>(1.0 - 0.3 * clamp(y, 0.0, 1.0), 1.0, 1.0);
	return mix(col * ab, r_water(y), g_hz * 0.8);
}

// The layer a creature lives in: its haze, and how far it shifts with the pointer.
fn r_layer(d: f32) {
	g_hz = d;
	g_ql = g_q + (g_ptr - vec2<f32>(0.5, 0.5)) * (1.0 - d) * vec2<f32>(0.045, 0.022);
}

// One gaussian splat: centre c, sigmas s, rotated by ang, peak alpha a.
fn r_sp(c: vec2<f32>, s0: vec2<f32>, ang: f32, col: vec3<f32>, a: f32) {
	let s = max(s0, vec2<f32>(g_cs * 0.42, g_cs * 0.42));
	let d = g_ql - c;
	let r = max(s.x, s.y) * 2.9;
	if (abs(d.x) > r || abs(d.y) > r) { return; }
	let cs = cos(ang);
	let sn = sin(ang);
	let u = d.x * cs + d.y * sn;
	let v = d.y * cs - d.x * sn;
	let e = 0.5 * (u * u / (s.x * s.x) + v * v / (s.y * s.y));
	if (e > 4.2) { return; }
	let wq = clamp(floor(a * exp(-e) * 3.0 + g_th) / 3.0, 0.0, 1.0);
	if (wq <= 0.0) { return; }
	let lit = 1.0 + 0.32 * clamp(-d.y / (max(s.x, s.y) * 1.5), -1.0, 1.0);
	g_col = mix(g_col, r_hz(col * lit, c.y), wq);
}

// A body's frame: local (x forward, y down), mirrored by dir, turned by ang.
fn r_fr(o: vec2<f32>, dir: f32, ang: f32, l: vec2<f32>) -> vec2<f32> {
	let x = l.x * dir;
	let cs = cos(ang);
	let sn = sin(ang);
	return o + vec2<f32>(x * cs - l.y * sn, x * sn + l.y * cs);
}

fn r_wrap(v: f32, m: f32) -> f32 {
	let span = g_a + 2.0 * m;
	return -m + fract((v + m) / span) * span;
}

fn r_jit(i: f32, j: f32) -> f32 {
	return 0.88 + 0.24 * r_h(vec2<f32>(i, j));
}

// Fish palettes: 0 back, 1 body, 2 belly, 3 fins, 4 tail, 5 accent.
fn r_fpal(kind: i32, k: i32) -> vec3<f32> {
	switch kind {
		case 0: {
			var p = array<vec3<f32>, 6>(vec3<f32>(0.86, 0.30, 0.04), vec3<f32>(1.0, 0.50, 0.12), vec3<f32>(1.0, 0.72, 0.42), vec3<f32>(0.96, 0.36, 0.06), vec3<f32>(0.96, 0.40, 0.08), vec3<f32>(0.99, 0.98, 0.95));
			return p[k];
		}
		case 1: {
			var p = array<vec3<f32>, 6>(vec3<f32>(0.10, 0.24, 0.74), vec3<f32>(0.18, 0.44, 0.94), vec3<f32>(0.40, 0.66, 1.0), vec3<f32>(0.08, 0.12, 0.34), vec3<f32>(1.0, 0.84, 0.14), vec3<f32>(0.05, 0.08, 0.26));
			return p[k];
		}
		case 2: {
			var p = array<vec3<f32>, 6>(vec3<f32>(0.92, 0.74, 0.08), vec3<f32>(0.99, 0.86, 0.26), vec3<f32>(1.0, 0.95, 0.66), vec3<f32>(0.98, 0.78, 0.10), vec3<f32>(0.99, 0.93, 0.62), vec3<f32>(0.10, 0.10, 0.16));
			return p[k];
		}
		case 3: {
			var p = array<vec3<f32>, 6>(vec3<f32>(0.34, 0.24, 0.42), vec3<f32>(0.50, 0.38, 0.58), vec3<f32>(0.72, 0.60, 0.72), vec3<f32>(0.30, 0.22, 0.40), vec3<f32>(0.30, 0.22, 0.40), vec3<f32>(0.88, 0.76, 0.90));
			return p[k];
		}
		default: {
			var p = array<vec3<f32>, 6>(vec3<f32>(0.08, 0.58, 0.50), vec3<f32>(0.20, 0.82, 0.66), vec3<f32>(0.66, 0.96, 0.82), vec3<f32>(0.94, 0.36, 0.66), vec3<f32>(0.94, 0.36, 0.66), vec3<f32>(0.98, 0.42, 0.72));
			return p[k];
		}
	}
}

fn r_prof(t: f32, h: f32) -> f32 {
	return 0.5 * h * sqrt(max(1.0 - t * t, 0.0)) * (0.55 + 0.45 * smoothstep(-1.0, 0.3, t));
}

fn r_fish(pos: vec2<f32>, dir: f32, ang: f32, len: f32, hgt: f32, kind: i32, d: f32, ph: f32) {
	r_layer(d);
	let rel = g_ql - pos;
	if (abs(rel.x) > len * 0.8 || abs(rel.y) > hgt * 0.9) { return; }
	let back = r_fpal(kind, 0);
	let body = r_fpal(kind, 1);
	let belly = r_fpal(kind, 2);
	let fin = r_fpal(kind, 3);
	let tail = r_fpal(kind, 4);
	let acc = r_fpal(kind, 5);
	let wag = sin(g_t * 6.5 + ph);
	let flap = sin(g_t * 4.0 + ph);
	let seed = f32(kind) * 13.0 + ph;

	// Tail: rays fanning back from the tail's root.
	for (var i = 0; i < 5; i = i + 1) {
		let a = (f32(i) - 2.0) * 0.3 + wag * 0.3;
		let c = vec2<f32>(-0.46 * len - 0.08 * len * cos(a), 0.09 * len * sin(a) + wag * 0.02 * hgt);
		r_sp(r_fr(pos, dir, ang, c), vec2<f32>(0.06 * len, 0.016 * len), ang - dir * a, tail * r_jit(f32(i), seed), 0.95);
	}
	// Dorsal and anal fins.
	for (var i = 0; i < 4; i = i + 1) {
		let t = (f32(i) - 1.5) * 0.18;
		let top = -r_prof(t, hgt) - 0.05 * hgt;
		r_sp(r_fr(pos, dir, ang, vec2<f32>(t * 0.48 * len, top)), vec2<f32>(0.045 * len, 0.03 * hgt + 0.012 * len), ang - dir * 0.3, fin * r_jit(f32(i), seed + 5.0), 0.9);
	}
	for (var i = 0; i < 2; i = i + 1) {
		let t = -0.25 + f32(i) * 0.2;
		r_sp(r_fr(pos, dir, ang, vec2<f32>(t * 0.48 * len, r_prof(t, hgt) + 0.04 * hgt)), vec2<f32>(0.04 * len, 0.012 * len), ang + dir * 0.4, fin, 0.85);
	}
	// Body: three rows of splats following the outline, like scales.
	for (var i = 0; i < 9; i = i + 1) {
		let t = -0.85 + f32(i) * 0.2125;
		let hh = r_prof(t, hgt);
		let slope = (r_prof(t + 0.05, hgt) - r_prof(t - 0.05, hgt)) / (0.1 * 0.48 * len);
		let bend = sin(g_t * 6.5 + ph - t * 2.2) * 0.03 * hgt * (1.0 - t);
		let x = t * 0.48 * len;
		for (var r = 0; r < 3; r = r + 1) {
			let v = (f32(r) - 1.0) * 0.6;
			var col = body;
			if (r == 0) { col = back; }
			if (r == 2) { col = belly; }
			let phi = atan(v * slope);
			let sy = max(hh * 0.42, 0.01 * len);
			r_sp(r_fr(pos, dir, ang, vec2<f32>(x, v * hh + bend)), vec2<f32>(0.07 * len, sy), ang + dir * phi, col * r_jit(f32(i * 3 + r), seed), 0.97);
		}
	}
	// Markings.
	if (kind == 0) {
		for (var i = 0; i < 3; i = i + 1) {
			let t = 0.5 - f32(i) * 0.52;
			let hh = r_prof(t, hgt);
			r_sp(r_fr(pos, dir, ang, vec2<f32>(t * 0.48 * len, 0.0)), vec2<f32>(0.022 * len, hh * 0.62), ang, acc, 1.0);
		}
	} else if (kind == 1) {
		for (var i = 0; i < 5; i = i + 1) {
			let t = -0.45 + f32(i) * 0.22;
			r_sp(r_fr(pos, dir, ang, vec2<f32>(t * 0.48 * len, -r_prof(t, hgt) * 0.35)), vec2<f32>(0.05 * len, 0.012 * len), ang, acc, 0.95);
		}
	} else if (kind == 2) {
		r_sp(r_fr(pos, dir, ang, vec2<f32>(0.33 * len, 0.0)), vec2<f32>(0.02 * len, r_prof(0.66, hgt) * 0.6), ang, acc, 1.0);
		r_sp(r_fr(pos, dir, ang, vec2<f32>(-0.2 * len, -r_prof(-0.4, hgt) * 0.4)), vec2<f32>(0.03 * len, 0.03 * len), ang, acc, 0.9);
	} else if (kind == 3) {
		for (var i = 0; i < 9; i = i + 1) {
			let t = -0.6 + r_h(vec2<f32>(f32(i), 4.0)) * 1.1;
			let v = (r_h(vec2<f32>(f32(i), 5.0)) - 0.5) * 1.1;
			r_sp(r_fr(pos, dir, ang, vec2<f32>(t * 0.48 * len, v * r_prof(t, hgt))), vec2<f32>(0.016 * len, 0.016 * len), ang, acc, 0.85);
		}
	} else {
		for (var i = 0; i < 6; i = i + 1) {
			let t = -0.6 + f32(i) * 0.22;
			r_sp(r_fr(pos, dir, ang, vec2<f32>(t * 0.48 * len, 0.0)), vec2<f32>(0.045 * len, 0.008 * len), ang, acc, 0.95);
		}
	}
	// Pectoral fin, eye.
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.1 * len, 0.1 * hgt)), vec2<f32>(0.06 * len, 0.02 * len), ang + dir * (0.6 + flap * 0.45), fin, 0.8);
	let eye = r_fr(pos, dir, ang, vec2<f32>(0.33 * len, -0.1 * hgt));
	let er = max(0.028 * len, g_cs * 0.5);
	r_sp(eye, vec2<f32>(er, er), 0.0, vec3<f32>(0.06, 0.07, 0.1), 1.0);
	r_sp(eye + vec2<f32>(-dir * er * 0.5, -er * 0.6), vec2<f32>(er * 0.3, er * 0.3), 0.0, vec3<f32>(1.0, 1.0, 1.0), 1.0);
}

fn r_swim(x0: f32, y0: f32, speed: f32, dir: f32, amp: f32, fq: f32, ph: f32, len: f32, hgt: f32, kind: i32, d: f32) {
	let x = r_wrap(x0 * (g_a + 2.0 * len) + g_t * speed * dir, len);
	let y = y0 + sin(g_t * fq + ph) * amp;
	let dy = cos(g_t * fq + ph) * amp * fq;
	let ang = dir * atan(dy / speed);
	r_fish(vec2<f32>(x, y), dir, ang, len, hgt, kind, d, ph);
}

fn r_school(d: f32) {
	let c = vec2<f32>(r_wrap(0.3 * (g_a + 0.5) - g_t * 0.04, 0.25), 0.36 + sin(g_t * 0.3) * 0.04);
	r_layer(d);
	let rel = g_ql - c;
	if (abs(rel.x) > 0.2 || abs(rel.y) > 0.11) { return; }
	for (var i = 0; i < 20; i = i + 1) {
		let fi = f32(i);
		let o = vec2<f32>(r_h(vec2<f32>(fi, 1.0)) - 0.5, r_h(vec2<f32>(fi, 2.0)) - 0.5) * vec2<f32>(0.3, 0.15);
		let ph = r_h(vec2<f32>(fi, 3.0)) * 6.28;
		let s = 0.8 + 0.4 * r_h(vec2<f32>(fi, 4.0));
		let p = c + o + vec2<f32>(sin(g_t * 1.1 + ph) * 0.006, cos(g_t * 0.9 + ph) * 0.005);
		let len = 0.03 * s;
		let wag = sin(g_t * 9.0 + ph);
		r_sp(p + vec2<f32>(len * 0.55, 0.0), vec2<f32>(len * 0.16, len * 0.12), wag * 0.5, vec3<f32>(0.32, 0.46, 0.64), 0.9);
		r_sp(p, vec2<f32>(len * 0.3, len * 0.11), 0.0, vec3<f32>(0.74, 0.86, 0.94), 1.0);
		r_sp(p + vec2<f32>(0.0, -len * 0.06), vec2<f32>(len * 0.24, len * 0.04), 0.0, vec3<f32>(0.36, 0.52, 0.72), 0.85);
	}
}

fn r_jelly(x0: f32, y0: f32, speed: f32, rr: f32, col: vec3<f32>, d: f32, ph: f32) {
	let p = max(sin(g_t * 1.7 + ph), 0.0);
	let c = vec2<f32>(x0 * g_a + sin(g_t * 0.22 + ph) * 0.03, 1.2 - fract(y0 + g_t * speed) * 1.45);
	r_layer(d);
	let rel = g_ql - c;
	if (abs(rel.x) > rr * 2.2 || rel.y < -rr * 2.0 || rel.y > rr * 4.0) { return; }
	let glow = col * 0.55 + vec3<f32>(0.45, 0.45, 0.45);
	r_sp(c, vec2<f32>(rr * 1.4, rr * 1.2), 0.0, col, 0.16);
	let bw = rr * (1.0 - 0.14 * p);
	let bh = rr * 0.75 * (1.0 + 0.12 * p);
	// Tentacles and oral arms.
	for (var i = 0; i < 5; i = i + 1) {
		let bx = (f32(i) - 2.0) * bw * 0.32;
		for (var k = 1; k < 8; k = k + 1) {
			let fk = f32(k);
			let tp = c + vec2<f32>(bx + sin(g_t * 1.4 - fk * 0.55 + f32(i) * 1.3) * fk * rr * 0.04, bh * 0.35 + fk * rr * 0.32);
			r_sp(tp, vec2<f32>(rr * 0.035, rr * 0.11), 0.0, col, 0.7 * (1.0 - fk / 9.0));
		}
	}
	for (var i = 0; i < 2; i = i + 1) {
		let side = f32(i) * 2.0 - 1.0;
		for (var k = 1; k < 5; k = k + 1) {
			let fk = f32(k);
			let tp = c + vec2<f32>(side * rr * 0.12 + sin(g_t * 1.1 + fk * 0.7 + side) * fk * rr * 0.05, bh * 0.3 + fk * rr * 0.26);
			r_sp(tp, vec2<f32>(rr * 0.09, rr * 0.13), 0.0, glow, 0.75);
		}
	}
	// Bell: splats around the dome, glow inside, a frilled rim.
	r_sp(c + vec2<f32>(0.0, -bh * 0.1), vec2<f32>(bw * 0.55, bh * 0.45), 0.0, col, 0.7);
	for (var i = 0; i < 9; i = i + 1) {
		let th = (f32(i) - 4.0) * 0.34;
		let dp = c + vec2<f32>(sin(th) * bw * 0.85, -cos(th) * bh * 0.85 + bh * 0.3);
		r_sp(dp, vec2<f32>(rr * 0.2, rr * 0.09), th, col * r_jit(f32(i), ph), 0.9);
	}
	r_sp(c + vec2<f32>(0.0, -bh * 0.25), vec2<f32>(bw * 0.3, bh * 0.25), 0.0, glow, 0.8);
	for (var i = 0; i < 6; i = i + 1) {
		let x = (f32(i) - 2.5) * bw * 0.34;
		r_sp(c + vec2<f32>(x, bh * 0.36 + sin(g_t * 3.0 + f32(i)) * rr * 0.03), vec2<f32>(rr * 0.13, rr * 0.06), 0.0, col, 0.85);
	}
	r_sp(c + vec2<f32>(-bw * 0.35, -bh * 0.5), vec2<f32>(rr * 0.07, rr * 0.05), 0.0, vec3<f32>(1.0, 1.0, 1.0), 0.8);
}

fn r_turtle(d: f32) {
	let len = 0.21;
	let dir = -1.0;
	let pos = vec2<f32>(r_wrap(0.6 * (g_a + 2.0 * len) - g_t * 0.016, len), 0.5 + sin(g_t * 0.4) * 0.015);
	let ang = dir * sin(g_t * 0.4 + 1.2) * 0.05;
	r_layer(d);
	let rel = g_ql - pos;
	if (abs(rel.x) > len * 0.9 || abs(rel.y) > len * 0.7) { return; }
	let stroke = sin(g_t * 1.1);
	let skin = vec3<f32>(0.60, 0.68, 0.56);
	let skin_d = vec3<f32>(0.42, 0.50, 0.40);
	let shell = vec3<f32>(0.50, 0.37, 0.22);
	let plate = vec3<f32>(0.70, 0.55, 0.32);
	let rim = vec3<f32>(0.30, 0.21, 0.12);
	let plas = vec3<f32>(0.88, 0.83, 0.66);
	// Far flippers.
	r_sp(r_fr(pos, dir, ang, vec2<f32>(-0.36 * len, 0.1 * len)), vec2<f32>(0.08 * len, 0.025 * len), ang + dir * 0.6, skin_d, 0.9);
	let fa = 1.3 + stroke * 0.7;
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.18 * len, 0.06 * len) + vec2<f32>(cos(fa), sin(fa)) * 0.14 * len), vec2<f32>(0.14 * len, 0.03 * len), ang + dir * fa, skin_d, 0.9);
	// Head and neck.
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.38 * len, 0.04 * len)), vec2<f32>(0.06 * len, 0.045 * len), ang, skin, 1.0);
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.48 * len, 0.02 * len)), vec2<f32>(0.065 * len, 0.05 * len), ang, skin, 1.0);
	// Shell: a base, plates in two rows, a darker rim, the plastron.
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.0, -0.01 * len)), vec2<f32>(0.3 * len, 0.14 * len), ang, shell, 1.0);
	for (var i = 0; i < 4; i = i + 1) {
		let x = (f32(i) - 1.5) * 0.13 * len;
		r_sp(r_fr(pos, dir, ang, vec2<f32>(x, -0.08 * len)), vec2<f32>(0.05 * len, 0.045 * len), ang, plate * r_jit(f32(i), 7.0), 1.0);
	}
	for (var i = 0; i < 5; i = i + 1) {
		let x = (f32(i) - 2.0) * 0.12 * len;
		r_sp(r_fr(pos, dir, ang, vec2<f32>(x, 0.02 * len)), vec2<f32>(0.045 * len, 0.04 * len), ang, shell * r_jit(f32(i), 8.0) * 1.15, 1.0);
	}
	for (var i = 0; i < 12; i = i + 1) {
		let th = 3.14159 + f32(i) / 11.0 * 3.14159;
		r_sp(r_fr(pos, dir, ang, vec2<f32>(cos(th) * 0.33 * len, sin(th) * 0.16 * len)), vec2<f32>(0.05 * len, 0.018 * len), ang + dir * (th + 1.5708), rim, 0.95);
	}
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.0, 0.11 * len)), vec2<f32>(0.26 * len, 0.025 * len), ang, plas, 0.95);
	// Near flippers.
	r_sp(r_fr(pos, dir, ang, vec2<f32>(-0.32 * len, 0.14 * len)), vec2<f32>(0.08 * len, 0.028 * len), ang + dir * (0.4 - stroke * 0.25), skin, 1.0);
	let fb = 1.15 + stroke * 0.8;
	r_sp(r_fr(pos, dir, ang, vec2<f32>(0.2 * len, 0.13 * len) + vec2<f32>(cos(fb), sin(fb)) * 0.16 * len), vec2<f32>(0.16 * len, 0.035 * len), ang + dir * fb, skin, 1.0);
	let eye = r_fr(pos, dir, ang, vec2<f32>(0.53 * len, -0.005 * len));
	r_sp(eye, vec2<f32>(g_cs * 0.5, g_cs * 0.5), 0.0, vec3<f32>(0.05, 0.05, 0.06), 1.0);
}

fn r_manta(d: f32) {
	let len = 0.34;
	let hd = vec2<f32>(0.5, -0.866);
	let run = (1.0 + 2.0 * len) / 0.866;
	let prog = fract(0.35 + g_t * 0.01);
	let pos = vec2<f32>(g_a * 0.12 - 0.3 * len, 1.0 + len) + hd * run * prog + vec2<f32>(sin(g_t * 0.2) * 0.02, 0.0);
	let ang = atan2(hd.y, hd.x) + sin(g_t * 0.2) * 0.05;
	r_layer(d);
	if (length(g_ql - pos) > len * 0.62) { return; }
	let flap = sin(g_t * 0.9);
	let span = 0.82 + 0.18 * flap;
	let dark = vec3<f32>(0.14, 0.21, 0.34);
	let pale = vec3<f32>(0.34, 0.42, 0.54);
	for (var k = 1; k < 6; k = k + 1) {
		r_sp(r_fr(pos, 1.0, ang, vec2<f32>(-0.12 * len - 0.07 * len * f32(k), sin(g_t * 1.5 - f32(k)) * 0.01 * len)), vec2<f32>(0.035 * len, 0.004), ang, dark, 0.9);
	}
	for (var i = 0; i < 2; i = i + 1) {
		let side = f32(i) * 2.0 - 1.0;
		for (var k = 0; k < 7; k = k + 1) {
			let f = f32(k) / 6.0;
			let l = vec2<f32>(len * (0.06 - 0.2 * f * f), side * len * (0.06 + 0.4 * f * span));
			r_sp(r_fr(pos, 1.0, ang, l), vec2<f32>(len * (0.075 - 0.045 * f), len * 0.045), ang + side * (0.5 + 0.5 * f), dark * r_jit(f32(k), side), 0.97);
		}
	}
	r_sp(r_fr(pos, 1.0, ang, vec2<f32>(0.0, 0.0)), vec2<f32>(0.13 * len, 0.08 * len), ang, dark, 1.0);
	r_sp(r_fr(pos, 1.0, ang, vec2<f32>(0.02 * len, 0.0)), vec2<f32>(0.08 * len, 0.045 * len), ang, pale, 0.6);
	for (var i = 0; i < 2; i = i + 1) {
		let side = f32(i) * 2.0 - 1.0;
		r_sp(r_fr(pos, 1.0, ang, vec2<f32>(0.15 * len, side * 0.05 * len)), vec2<f32>(0.035 * len, 0.012 * len), ang + side * 0.3, dark, 1.0);
	}
}

fn r_kelp(x0: f32, h: f32, d: f32, ph: f32, w: f32) {
	let x = x0 * g_a;
	r_layer(d);
	if (g_ql.y < 1.0 - h - 0.06 || abs(g_ql.x - x) > 0.08) { return; }
	var prev = vec2<f32>(x, 1.02);
	for (var s = 1; s <= 12; s = s + 1) {
		let f = f32(s) / 12.0;
		let sway = sin(g_t * 0.7 + ph + f32(s) * 0.35) * f * 0.04 * w;
		let p = vec2<f32>(x + sway, 1.02 - f * h);
		let ang = atan2(p.x - prev.x, prev.y - p.y);
		let col = mix(vec3<f32>(0.12, 0.42, 0.20), vec3<f32>(0.48, 0.66, 0.22), f) * r_jit(f32(s), ph);
		r_sp((p + prev) * 0.5, vec2<f32>(0.0045 * w, h / 12.0 * 0.55), ang, col, 1.0);
		if (s > 1 && s < 12) {
			var side = -1.0;
			if ((s & 1) == 0) { side = 1.0; }
			let leaf = 0.85 + 0.3 * sin(g_t * 0.9 + ph + f32(s));
			r_sp(p + vec2<f32>(side * 0.014 * w, 0.004), vec2<f32>(0.016 * w, 0.005 * w), side * leaf, col * 1.12, 0.9);
		}
		prev = p;
	}
}

fn r_coral(x0: f32, size: f32, kind: i32, col: vec3<f32>, d: f32, ph: f32) {
	let b = vec2<f32>(x0 * g_a, 0.975 - (1.0 - d) * 0.012);
	r_layer(d);
	if (abs(g_ql.x - b.x) > size * 1.4 || g_ql.y < b.y - size * 1.6) { return; }
	if (kind == 0) {
		for (var i = 0; i < 7; i = i + 1) {
			let a = (f32(i) - 3.0) * 0.3 + sin(g_t * 0.5 + ph) * 0.04;
			r_sp(b + vec2<f32>(sin(a), -cos(a)) * size * 0.6, vec2<f32>(size * 0.09, size * 0.5), a, col * r_jit(f32(i), ph), 0.95);
		}
	} else if (kind == 1) {
		r_sp(b, vec2<f32>(size * 0.75, size * 0.42), 0.0, col, 1.0);
		for (var i = 0; i < 5; i = i + 1) {
			let o = vec2<f32>((f32(i) - 2.0) * size * 0.28, -size * 0.18 - abs(f32(i) - 2.0) * -size * 0.06);
			r_sp(b + o, vec2<f32>(size * 0.1, size * 0.16), 0.0, col * 1.25, 0.9);
		}
	} else if (kind == 2) {
		r_sp(b, vec2<f32>(size * 0.32, size * 0.22), 0.0, col * 0.8, 1.0);
		for (var i = 0; i < 9; i = i + 1) {
			let a = (f32(i) - 4.0) * 0.26 + sin(g_t * 1.2 + ph + f32(i) * 0.5) * 0.22;
			r_sp(b + vec2<f32>(sin(a), -cos(a)) * size * 0.5 - vec2<f32>(0.0, size * 0.2), vec2<f32>(size * 0.06, size * 0.36), a, col * r_jit(f32(i), ph), 0.95);
		}
	} else {
		for (var i = 0; i < 4; i = i + 1) {
			let hh = 0.6 + 0.5 * r_h(vec2<f32>(f32(i), ph));
			let o = vec2<f32>((f32(i) - 1.5) * size * 0.3, -size * 0.5 * hh);
			r_sp(b + o, vec2<f32>(size * 0.08, size * 0.5 * hh), 0.0, col, 1.0);
			r_sp(b + o * 2.0 + vec2<f32>(0.0, size * 0.02), vec2<f32>(size * 0.1, size * 0.08), 0.0, col * 1.35, 0.95);
		}
	}
}

fn r_background(q: vec2<f32>) -> vec3<f32> {
	// Banded water, dithered only where two bands meet.
	let bands = 18.0;
	var c = r_water((floor(q.y * bands + g_th) + 0.5) / bands);
	// Caustic shimmer under the surface.
	let cz = sin(q.x * 38.0 + g_t * 1.3 + sin(q.y * 22.0 - g_t) * 1.5) * sin(q.x * 21.0 - g_t * 0.9 + q.y * 30.0);
	let cq = floor(max(cz, 0.0) * 0.12 * (1.0 - smoothstep(0.0, 0.35, q.y)) / 0.04 + g_th) * 0.04;
	c = c + vec3<f32>(0.6, 0.9, 1.0) * cq;
	// Light rays.
	var ray = 0.0;
	for (var i = 0; i < 5; i = i + 1) {
		let fi = f32(i);
		let x0 = (fi + 0.2 + 0.6 * r_h(vec2<f32>(fi, 9.0))) / 5.0 * g_a;
		let slant = 0.15 + 0.2 * r_h(vec2<f32>(fi, 10.0));
		let wd = (0.02 + 0.03 * r_h(vec2<f32>(fi, 11.0))) * (1.0 + q.y * 1.5);
		let rx = q.x - (x0 + q.y * slant + sin(g_t * 0.22 + fi * 1.7) * 0.04);
		ray = ray + (1.0 - smoothstep(0.0, wd, abs(rx))) * (0.05 + 0.05 * r_h(vec2<f32>(fi, 12.0))) * (0.75 + 0.25 * sin(g_t * 0.8 + fi * 2.0));
	}
	let rq = floor(ray * pow(1.0 - clamp(q.y, 0.0, 1.0), 1.4) / 0.035 + g_th) * 0.035;
	c = c + vec3<f32>(0.75, 0.95, 1.0) * rq;
	// The surface.
	let sh = 0.012 + 0.006 * sin(q.x * 28.0 + g_t * 1.1) + 0.004 * sin(q.x * 9.0 - g_t * 0.6);
	if (q.y < sh) {
		c = mix(c, vec3<f32>(0.75, 0.93, 0.97), 0.55);
	} else if (q.y < sh + g_cs) {
		c = mix(c, vec3<f32>(0.92, 0.99, 1.0), 0.6);
	}
	// The sea floor.
	let fx = q.x + (g_ptr.x - 0.5) * 0.01;
	let fh = 0.05 + 0.018 * sin(fx * 4.0 + 1.0) + 0.01 * sin(fx * 11.0) + 0.004 * sin(fx * 29.0);
	if (q.y > 1.0 - fh) {
		let g = r_h(floor(q / g_cs));
		var s = mix(vec3<f32>(0.42, 0.45, 0.42), r_water(1.0), 0.45) * (0.9 + 0.16 * g);
		if (q.y < 1.0 - fh + g_cs) { s = s * 1.3; }
		c = s;
	}
	return c;
}

fn r_scene() {
	// Far.
	r_manta(0.62);
	r_kelp(0.33, 0.55, 0.55, 2.1, 1.0);
	r_kelp(0.63, 0.6, 0.6, 4.4, 1.1);
	r_kelp(0.94, 0.52, 0.5, 5.9, 0.9);
	r_swim(0.1, 0.42, 0.012, 1.0, 0.015, 0.3, 1.0, 0.24, 0.095, 3, 0.68);
	r_swim(0.6, 0.28, 0.025, -1.0, 0.02, 0.4, 2.0, 0.09, 0.047, 1, 0.55);
	r_jelly(0.2, 0.0, 0.012, 0.035, vec3<f32>(1.0, 0.55, 0.82), 0.6, 1.0);
	r_jelly(0.75, 0.4, 0.016, 0.03, vec3<f32>(0.75, 0.6, 1.0), 0.5, 2.0);
	r_swim(0.3, 0.6, 0.03, 1.0, 0.02, 0.45, 3.0, 0.085, 0.03, 4, 0.45);
	// Middle.
	r_school(0.32);
	r_coral(0.06, 0.05, 0, vec3<f32>(0.42, 0.86, 0.80), 0.35, 1.0);
	r_coral(0.15, 0.045, 2, vec3<f32>(0.80, 0.50, 0.92), 0.3, 2.0);
	r_coral(0.27, 0.04, 3, vec3<f32>(1.0, 0.62, 0.45), 0.25, 3.0);
	r_coral(0.4, 0.055, 0, vec3<f32>(1.0, 0.45, 0.58), 0.4, 4.0);
	r_coral(0.53, 0.04, 1, vec3<f32>(0.72, 0.86, 0.40), 0.2, 5.0);
	r_coral(0.69, 0.035, 2, vec3<f32>(1.0, 0.55, 0.65), 0.15, 6.0);
	r_coral(0.8, 0.05, 0, vec3<f32>(0.50, 0.85, 0.85), 0.3, 7.0);
	r_coral(0.89, 0.055, 0, vec3<f32>(1.0, 0.50, 0.66), 0.35, 8.0);
	r_coral(0.97, 0.04, 3, vec3<f32>(0.95, 0.80, 0.40), 0.2, 9.0);
	r_turtle(0.22);
	r_swim(0.8, 0.7, 0.022, -1.0, 0.015, 0.35, 4.0, 0.085, 0.067, 2, 0.3);
	r_jelly(0.45, 0.7, 0.014, 0.045, vec3<f32>(1.0, 0.75, 0.6), 0.3, 3.0);
	// Near.
	r_swim(0.45, 0.63, 0.028, 1.0, 0.02, 0.5, 5.0, 0.095, 0.046, 0, 0.15);
	r_swim(0.15, 0.5, 0.035, 1.0, 0.025, 0.3, 6.0, 0.16, 0.084, 1, 0.08);
	r_swim(0.9, 0.78, 0.024, -1.0, 0.02, 0.45, 7.0, 0.11, 0.054, 0, 0.05);
	r_jelly(0.9, 0.2, 0.018, 0.04, vec3<f32>(0.62, 0.86, 1.0), 0.15, 4.0);
	r_kelp(0.04, 0.5, 0.25, 0.3, 1.1);
	r_kelp(0.17, 0.38, 0.12, 1.2, 1.0);
	r_kelp(0.49, 0.42, 0.18, 3.3, 1.2);
	r_kelp(0.78, 0.45, 0.08, 5.1, 1.3);
}

fn r_specks(q: vec2<f32>) {
	// Bubbles: pixel rings rising.
	for (var i = 0; i < 14; i = i + 1) {
		let fi = f32(i);
		let x = r_h(vec2<f32>(fi, 21.0)) * g_a + sin(g_t * 2.0 + fi * 3.0) * 0.006 + (g_ptr.x - 0.5) * 0.03;
		let y = 1.05 - fract(r_h(vec2<f32>(fi, 23.0)) + g_t * (0.05 + 0.06 * r_h(vec2<f32>(fi, 22.0)))) * 1.15;
		var rad = 1.0;
		if (r_h(vec2<f32>(fi, 24.0)) > 0.6) { rad = 2.0; }
		let ctr = (floor(vec2<f32>(x, y) / g_cs) + 0.5) * g_cs;
		let dc = (q - ctr) / g_cs;
		let dd = length(dc);
		if (abs(dd - rad) < 0.5) {
			g_col = mix(g_col, vec3<f32>(0.85, 0.96, 1.0), 0.6);
		}
		if (rad > 1.5 && abs(dc.x + 1.0) < 0.1 && abs(dc.y + 1.0) < 0.1) {
			g_col = vec3<f32>(1.0, 1.0, 1.0);
		}
	}
	// Marine snow drifting down.
	for (var l = 0; l < 2; l = l + 1) {
		let fl = f32(l);
		let blk = g_cs * (4.0 + fl * 2.0);
		let qq = q - vec2<f32>(g_t * (0.004 + fl * 0.003), -g_t * (0.012 + fl * 0.01));
		let b = floor(qq / blk);
		if (r_h(b + vec2<f32>(fl * 17.0, 3.0)) > 0.94) {
			let sp = b * blk + (floor(vec2<f32>(r_h(b + 1.3), r_h(b + 2.7)) * (blk / g_cs)) + 0.5) * g_cs;
			let dd = abs(qq - sp);
			if (dd.x < g_cs * 0.5 && dd.y < g_cs * 0.5) {
				g_col = mix(g_col, vec3<f32>(0.86, 0.93, 0.95), 0.45 - fl * 0.15);
			}
		}
	}
}

fn run(input: PassInput) -> vec4<f32> {
	let pa = input.params[0];
	let cell = floor(input.pixel);
	let hgt = max(input.size.y, 1.0);
	g_cs = 1.0 / hgt;
	g_a = input.size.x / hgt;
	g_t = input.time + 40.0;
	g_ptr = pa.xy;
	g_th = r_bayer(cell);
	let q = (cell + 0.5) / hgt;
	g_col = r_background(q);
	// Rows waver a pixel, like light bending through water.
	g_q = q + vec2<f32>(round(sin(cell.y * 0.21 + g_t * 1.6) * 0.6) * g_cs, 0.0);
	r_scene();
	r_specks(q);
	// Rounded to a small palette.
	let n = 18.0;
	return vec4<f32>(clamp(floor(g_col * n + 0.5) / n, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}
]==]

M.SHOW = [==[
fn layer(input: LayerInput) -> vec4<f32> {
	let sz = vec2<f32>(zgx_reef_size());
	let uv = (floor(input.p / max(input.size, vec2<f32>(1.0)) * sz) + 0.5) / sz;
	let c = zgx_reef(uv);
	let pb = input.params[1];
	return vec4<f32>(c.rgb * pb.y, pb.x);
}
]==]

return M
