// ---- what moves: fish, a turtle, a manta, jellyfish, kelp; then light
// shafts, snow and bubbles, and the palette. Drawn every frame, over the
// still scenery's kept pixels. --------------------------------------------------

var<private> g_best: f32;
var<private> g_id: i32;
var<private> g_n: vec3<f32>;
var<private> g_ao: f32;
var<private> g_m: i32;
var<private> g_det: f32;
var<private> g_fp: vec3<f32>;
var<private> g_fish: vec4<f32>;
var<private> g_fph: f32;
var<private> g_jr: f32;
var<private> g_jp: f32;
var<private> g_jmat: i32;
var<private> g_kp: array<vec3<f32>, 6>;
var<private> g_rs: i32;
var<private> g_rc: i32;

// A fish, nose along +x, by its kind, length, height and width.
fn sr_fish(p0: vec3<f32>) -> f32 {
	let L = g_fish.y;
	let H = g_fish.z;
	let W = g_fish.w;
	var p = p0;
	// Swimming: a wave down the body, widest at the tail.
	let u = clamp(0.5 - p.x / L, 0.0, 1.3);
	p.z = p.z - sin(g_t * 7.0 + g_fph - u * 3.0) * 0.06 * L * u * u;
	g_fp = p;
	var d = sd_ell(p, vec3<f32>(0.06 * L, 0.0, 0.0), vec3<f32>(0.4 * L, 0.5 * H, 0.5 * W));
	d = sr_smin(d, sd_ell(p, vec3<f32>(-0.27 * L, 0.0, 0.0), vec3<f32>(0.27 * L, 0.25 * H, 0.32 * W)), 0.1 * L);
	// The tail, forked.
	var tf = sd_ell(p, vec3<f32>(-0.55 * L, 0.0, 0.0), vec3<f32>(0.17 * L, 0.42 * H, 0.03 * L)) + sr_rays(-(p.x + 0.36 * L), p.y, 22.0);
	tf = max(tf, -(length(p - vec3<f32>(-0.8 * L, 0.0, 0.0)) - 0.2 * L));
	d = sr_smin(d, tf, 0.04 * L);
	// Dorsal and anal fins.
	d = sr_smin(d, sd_ell(p, vec3<f32>(-0.03 * L, 0.47 * H, 0.0), vec3<f32>(0.27 * L, 0.2 * H, 0.026 * L)), 0.03 * L);
	d = sr_smin(d, sd_ell(p, vec3<f32>(-0.16 * L, -0.44 * H, 0.0), vec3<f32>(0.14 * L, 0.15 * H, 0.024 * L)), 0.03 * L);
	// Pectoral fins, sculling.
	let q = vec3<f32>(p.x, p.y, abs(p.z));
	let scull = sin(g_t * 5.0 + g_fph) * 0.03 * L;
	d = sr_smin(d, sd_ell(q, vec3<f32>(0.08 * L, -0.12 * H, 0.5 * W + 0.05 * L + scull), vec3<f32>(0.1 * L, 0.05 * H + 0.012, 0.06 * L)), 0.02 * L);
	return d;
}

// Its markings, from where on it the ray landed.
fn sr_fish_mat() {
	let kind = i32(g_fish.x);
	let L = g_fish.y;
	let H = g_fish.z;
	let W = g_fish.w;
	let p = g_fp;
	let x = p.x / L;
	let y = p.y / H;
	var m = 3;
	if (kind == 0) {
		// Clownfish: orange, three white bands edged in dark, dark fin tips.
		let b = min(abs(x - 0.2), min(abs(x + 0.05), abs(x + 0.33)));
		if (b < 0.055) {
			m = 2;
		}
	} else if (kind == 1) {
		// Tang: blue, a dark sweep along the back, a yellow tail.
		m = 7;
		if (y > 0.1 && y < 0.36 - 0.5 * abs(x + 0.12) && x > -0.4 && x < 0.16) {
			m = 9;
		}
		if (x < -0.43) {
			m = 8;
		}
	} else if (kind == 2) {
		// Bannerfish: white, two bold dark bands, yellow toward the tail.
		m = 2;
		if ((x > 0.1 && x < 0.26) || (x > -0.24 && x < -0.08)) {
			m = 9;
		}
		if (x < -0.24 || y > 0.56) {
			m = 8;
		}
		if (x < -0.6) {
			m = 9;
		}
	} else {
		// Grouper: violet, mottled.
		m = 5;
	}
	if (length(vec3<f32>(p.x - 0.3 * L, p.y - 0.1 * H, abs(p.z) - 0.4 * W)) < 0.05 * L + 0.006) {
		m = 9;
	}
	// Scales, and a paler belly.
	let w = sr_cells(p * (5.0 / L), 3.0);
	g_det = clamp(0.5 + 0.2 * (0.45 - w.x) + 0.5 * y, 0.0, 1.0);
	if (kind == 3 && w.x < 0.22) {
		g_det = g_det + 0.3;
	}
	g_m = m;
}

fn sr_turtle(p: vec3<f32>) -> f32 {
	var d = sd_ell(p, vec3<f32>(0.0, 0.03, 0.0), vec3<f32>(0.36, 0.13, 0.27));
	d = sr_smin(d, sd_ell(p, vec3<f32>(0.0, -0.03, 0.0), vec3<f32>(0.33, 0.08, 0.24)), 0.03);
	let q = vec3<f32>(p.x, p.y, abs(p.z));
	// Head and neck.
	var sk = sr_smin(sd_ell(p, vec3<f32>(0.45, 0.02, 0.0), vec3<f32>(0.11, 0.075, 0.08)), sd_cap(p, vec3<f32>(0.3, 0.0, 0.0), vec3<f32>(0.4, 0.01, 0.0), 0.06, 0.06), 0.03);
	// Front flippers, beating like wings about the shoulder.
	let fa = 0.55 * sin(g_t * 1.5);
	let s = q - vec3<f32>(0.2, -0.02, 0.2);
	let cf = cos(fa);
	let sf = sin(fa);
	let sr = vec3<f32>(s.x + 0.35 * s.z, s.y * cf - s.z * sf, s.y * sf + s.z * cf);
	sk = min(sk, sd_ell(sr, vec3<f32>(0.0, 0.0, 0.26), vec3<f32>(0.11, 0.024, 0.27)) * 0.9);
	// Rear flippers and a stub of a tail.
	sk = min(sk, sd_ell(q, vec3<f32>(-0.35, -0.03, 0.17), vec3<f32>(0.11, 0.02, 0.07)));
	sk = min(sk, sd_cap(p, vec3<f32>(-0.34, -0.02, 0.0), vec3<f32>(-0.45, -0.03, 0.0), 0.025, 0.008));
	g_mat = 12;
	if (sk < d) {
		g_mat = 13;
	}
	return sr_smin(d, sk, 0.02);
}

fn sr_manta(p0: vec3<f32>) -> f32 {
	var p = p0;
	// Wings rising and falling, more toward the tips.
	let az = abs(p.z);
	p.y = p.y - 0.3 * sin(g_t * 0.9 - az * 0.8) * az * az * 0.55;
	g_fp = p;
	let q = vec3<f32>(p.x, p.y, az);
	var d = sd_ell(p, vec3<f32>(0.0), vec3<f32>(0.5, 0.09, 0.3));
	d = sr_smin(d, sd_ell(q, vec3<f32>(-0.02, 0.0, 0.5), vec3<f32>(0.36, 0.045, 0.55)), 0.1);
	d = sr_smin(d, sd_ell(q, vec3<f32>(-0.16, 0.0, 0.95), vec3<f32>(0.18, 0.03, 0.32)), 0.08);
	d = sr_smin(d, sd_cap(q, vec3<f32>(0.42, -0.01, 0.1), vec3<f32>(0.62, -0.03, 0.13), 0.04, 0.02), 0.03);
	return min(d, sd_cap(p, vec3<f32>(-0.45, 0.0, 0.0), vec3<f32>(-1.3, 0.0, 0.0), 0.03, 0.012));
}

// A jellyfish about its bell's centre: the bell pulses, the tentacles trail.
fn sr_jelly(p0: vec3<f32>) -> f32 {
	let r = g_jr;
	let s = 1.0 - 0.16 * g_jp;
	let p = vec3<f32>(p0.x / s, p0.y / (1.0 + 0.12 * g_jp), p0.z / s);
	var bell = max(length(p) - r, -(length(p + vec3<f32>(0.0, 0.45 * r, 0.0)) - 0.98 * r));
	bell = max(bell, -(p.y + 0.3 * r)) * s;
	var tn = 1e9;
	if (p0.y < 0.1 * r) {
		let dep = max(-p0.y, 0.0);
		for (var k = 0; k < 6; k = k + 1) {
			let fk = f32(k);
			let a = fk * 1.047 + 0.3;
			let o = vec3<f32>(
				cos(a) * 0.6 * r + sin(p0.y * 12.0 + g_t * 2.2 + fk * 1.7) * 0.11 * dep,
				0.0,
				sin(a) * 0.6 * r + cos(p0.y * 10.0 + g_t * 1.8 + fk) * 0.09 * dep
			);
			tn = min(tn, sd_cap(p0 - o, vec3<f32>(0.0, -0.15 * r, 0.0), vec3<f32>(0.0, -(2.2 + 0.25 * fk) * r, 0.0), 0.02, 0.013));
		}
		// Two frilled arms under the bell.
		for (var k = 0; k < 2; k = k + 1) {
			let fk = f32(k);
			let o = vec3<f32>((fk - 0.5) * 0.3 * r + sin(p0.y * 16.0 + g_t * 2.6 + fk * 2.0) * 0.06 * dep, 0.0, sin(p0.y * 9.0 + g_t + fk) * 0.05 * dep);
			tn = min(tn, sd_cap(p0 - o, vec3<f32>(0.0, -0.1 * r, 0.0), vec3<f32>(0.0, -1.5 * r, 0.0), 0.2 * r, 0.06 * r));
		}
	}
	g_mat = 0;
	if (tn < bell) {
		g_mat = 1;
	}
	return min(bell, tn);
}

fn sr_kelp(p0: vec3<f32>) -> f32 {
	// Swaying, more the higher up.
	var p = p0;
	let k = max(p0.y - K_FLOOR, 0.0);
	p.x = p.x - k * k * 0.07 * sin(g_t * 0.9 + p0.z * 3.0 + p0.x * 2.0);
	p.z = p.z - k * k * 0.05 * cos(g_t * 0.7 + p0.x * 3.0);
	var d = 1e9;
	for (var i = 0; i < 5; i = i + 1) {
		let a = g_kp[i];
		let b = g_kp[i + 1];
		let n = f32(i + 1) / 5.0;
		d = sr_smin(d, sd_cap(p, a, b, 0.026 * (1.1 - n * 0.6), 0.026 * (1.1 - (n + 0.2) * 0.6)), 0.02);
		// A pair of blades, reaching up and out.
		let q = p - b;
		let bl = 0.1 + 0.05 * (1.0 - n);
		for (var k = 0; k < 2; k = k + 1) {
			let sgn = f32(k) * 2.0 - 1.0;
			let lx = q.x * sgn * 0.74 + q.y * 0.67 - bl;
			let ly = -q.x * sgn * 0.67 + q.y * 0.74;
			d = sr_smin(d, sd_ell(vec3<f32>(lx, ly, q.z), vec3<f32>(0.0), vec3<f32>(bl, 0.034, 0.013)), 0.015);
		}
	}
	return d;
}

fn sr_part(id: i32, p: vec3<f32>) -> f32 {
	switch id {
		case 1: { return sr_fish(p); }
		case 2: { return sr_turtle(p); }
		case 3: { return sr_manta(p); }
		case 4: { return sr_jelly(p); }
		default: { return sr_kelp(p); }
	}
}

// One creature along the ray, inside its box: the nearest hit so far is
// kept, with its material, normal and occlusion.
fn sr_try(id: i32, o: vec3<f32>, d: vec3<f32>, R: mat3x3<f32>, lo: vec3<f32>, hi: vec3<f32>, steps: i32, relax: f32) {
	let ds = select(d, vec3<f32>(1e-6), abs(d) < vec3<f32>(1e-6));
	let ta = (lo - o) / ds;
	let tb = (hi - o) / ds;
	let tn = min(ta, tb);
	let tx = max(ta, tb);
	let t0 = max(max(tn.x, tn.y), max(tn.z, 0.0));
	let t1 = min(min(tx.x, tx.y), min(tx.z, g_best));
	if (t0 >= t1) {
		return;
	}
	var t = t0;
	for (var i = 0; i < steps; i = i + 1) {
		let p = o + d * t;
		let dist = sr_part(id, p);
		if (dist < 0.004) {
			g_best = t;
			g_id = id;
			// Its material, from this last look at it.
			if (id == 1) {
				sr_fish_mat();
			} else if (id == 2) {
				g_m = g_mat;
				let w = sr_cells(p * vec3<f32>(7.0, 9.0, 7.0), 4.0);
				g_det = 0.5 + 0.3 * (sr_noise(p * 14.0) - 0.5);
				if (g_m == 12) {
					if (w.y < 0.09) {
						g_det = g_det - 0.34;
					}
					if (p.y < -0.035) {
						g_m = 8;
					}
				} else if (w.x < 0.3) {
					g_det = g_det + 0.25;
				}
			} else if (id == 3) {
				g_m = 14;
				g_det = 0.5;
				if (g_fp.y < -0.012) {
					g_m = 2;
					g_det = 0.42;
				}
			} else if (id == 4) {
				g_m = g_jmat;
				g_det = clamp(0.5 + 0.9 * p.y / g_jr, 0.1, 0.9) - 0.15 * f32(g_mat);
			} else {
				g_m = 6;
				g_det = 0.5 + 0.3 * sin(p.y * 40.0);
			}
			let k = 0.007;
			let nl = normalize(vec3<f32>(
				sr_part(id, p + vec3<f32>(k, 0.0, 0.0)),
				sr_part(id, p + vec3<f32>(0.0, k, 0.0)),
				sr_part(id, p + vec3<f32>(0.0, 0.0, k))
			) - dist);
			let h = 0.02;
			var occ = max(0.0, 1.0 - sr_part(id, p + nl * 3.0 * h) / (3.0 * h));
			occ = occ + max(0.0, 1.0 - sr_part(id, p + nl * 8.0 * h) / (8.0 * h));
			g_ao = max(0.0, 1.0 - occ / 1.6);
			g_n = R * nl;
			return;
		}
		t = t + dist * relax;
		if (t > t1) {
			return;
		}
	}
}

// ---- colour ----------------------------------------------------------------

fn sr_ramp(start: i32, count: i32, l0: f32) -> vec3<f32> {
	g_rs = start;
	g_rc = count;
	let l = clamp(l0, 0.0, 1.0) * f32(count - 1);
	let i = i32(floor(l));
	return mix(K_PAL[start + i], K_PAL[start + min(i + 1, count - 1)], fract(l));
}

// A material lit by `l`, through its ramp of the palette.
fn sr_colour(m: i32, l: f32, e: f32, p: vec3<f32>) -> vec3<f32> {
	switch m {
		case 0: { return sr_ramp(0, 10, l * 0.62); }
		case 1: { return sr_ramp(0, 10, l * 0.7 + 0.04); }
		case 2: { return sr_ramp(0, 10, l * 0.42 + 0.6); }
		case 3: { return sr_ramp(10, 6, l * 0.82 + 0.06); }
		case 4: { return sr_ramp(21, 5, l); }
		case 5: { return sr_ramp(26, 5, l); }
		case 6: { return sr_ramp(16, 5, l * 0.9 + 0.1); }
		case 7: { return sr_ramp(31, 5, l); }
		case 8: { return sr_ramp(36, 4, l * 0.9 + 0.1); }
		case 9: { return sr_ramp(0, 10, l * 0.2); }
		case 10: { return sr_ramp(10, 6, 0.64 + 0.12 * sin(e * 2.0 + p.x * 20.0)); }
		case 12: { return sr_ramp(10, 6, l * 0.6 + 0.02); }
		case 13: { return sr_ramp(16, 5, l * 0.8 + 0.1); }
		case 14: { return sr_ramp(0, 10, l * 0.38 + 0.06); }
		case 15: { return sr_ramp(26, 5, 0.2 + 0.8 * l); }
		case 16: { return sr_ramp(21, 5, 0.2 + 0.8 * l); }
		case 17: { return sr_ramp(0, 10, 0.3 + 0.62 * l); }
		case 18: { return sr_ramp(21, 5, 0.35 + 0.65 * l); }
		case 19: { return sr_ramp(10, 6, l * 0.85 + 0.1); }
		case 20: { return sr_ramp(21, 5, l * 0.95 + 0.05); }
		default: { return sr_ramp(0, 10, l); }
	}
}

// The nearest palette colour, among the water's ramp and the ramp at
// [rs, rs + rc): a surface keeps to its own family of colours however the
// water between tints it (an orange coral never turns green).
fn sr_nearest(col: vec3<f32>, cell: vec2<f32>, dither: f32, rs: i32, rc: i32, warm: bool) -> vec3<f32> {
	var c1 = col;
	var c2 = col;
	var d1 = 1e9;
	var d2 = 1e9;
	for (var i = 0; i < N_PAL; i = i + 1) {
		if (i >= 10 && (i < rs || i >= rs + rc) && !(warm && i < 16)) {
			continue;
		}
		let pc = K_PAL[i];
		let e = col - pc;
		let w = e * vec3<f32>(0.30, 0.59, 0.11);
		let d = dot(w, w) + 0.25 * dot(e, e);
		if (d < d1) {
			d2 = d1;
			c2 = c1;
			d1 = d;
			c1 = pc;
		} else if (d < d2) {
			d2 = d;
			c2 = pc;
		}
	}
	let axis = c2 - c1;
	let t = clamp(dot(col - c1, axis) / max(dot(axis, axis), 1e-5), 0.0, 0.5);
	if (sr_bayer(cell) < t * dither) {
		return c2;
	}
	return c1;
}

// How light the open water is, down the screen (0 at the top).
fn sr_water(v: f32) -> f32 {
	return 0.03 + 0.2 * pow(1.0 - clamp(v, 0.0, 1.0), 1.5);
}

fn sr_yaw(a: f32) -> mat3x3<f32> {
	let c = cos(a);
	let s = sin(a);
	return mat3x3<f32>(vec3<f32>(c, 0.0, s), vec3<f32>(0.0, 1.0, 0.0), vec3<f32>(-s, 0.0, c));
}

// Across the view and round again, at depth z: where along x.
fn sr_cross(x0: f32, speed: f32, dir: f32, z: f32, margin: f32, aspect: f32, e: f32) -> f32 {
	let hw = aspect * K_TAN * (g_ro.z - z) + margin;
	return dir * (-hw + fract(x0 + e * speed / (2.0 * hw)) * 2.0 * hw);
}

// ---- a pixel ---------------------------------------------------------------

fn run(input: PassInput) -> vec4<f32> {
	let pa = input.params[0];
	let pb = input.params[1];
	let pc = input.params[2];
	let cell = floor(input.pixel);
	let res = input.size;
	let aspect = res.x / max(res.y, 1.0);
	let e = input.time * max(pa.w, 0.05) + 20.0;
	g_t = e;
	g_thr = sr_bayer(cell + 2.0) * 0.96 + 0.02;
	sr_camera(cell, res, pb);
	let ro = g_ro;
	let rd = g_rd;
	let ident = mat3x3<f32>(vec3<f32>(1.0, 0.0, 0.0), vec3<f32>(0.0, 1.0, 0.0), vec3<f32>(0.0, 0.0, 1.0));

	// The still scenery, as kept.
	let st = zgx_ground_texel(vec2<i32>(cell));
	var sdep = 1e4;
	if (st.z > 0.0 && st.z < 1e3) {
		sdep = st.z;
	}
	g_best = sdep;
	g_id = -1;

	// Fish.
	for (var i = 0; i < N_FISH; i = i + 1) {
		let fa = K_FISH_A[i];
		let fb = K_FISH_B[i];
		let fc = K_FISH_C[i];
		let L = fa.y;
		var pos = vec3<f32>(0.0);
		var yaw = 0.0;
		if (fc.z > 0.5) {
			// Round the anemone.
			let ang = e * fb.w * fc.x + fc.y;
			pos = K_AN_C + vec3<f32>(fc.w * cos(ang), 0.42 + 0.08 * sin(e * 0.9 + fc.y), fc.w * 0.7 * sin(ang));
			yaw = atan2(0.7 * cos(ang) * fc.x, -sin(ang) * fc.x);
		} else {
			let z = fb.z + 0.25 * sin(e * 0.21 + fc.y * 1.7);
			pos = vec3<f32>(sr_cross(fb.x, fb.w, fc.x, z, L + 0.3, aspect, e), fb.y + 0.09 * sin(e * 0.5 + fc.y), z);
			yaw = 0.12 * sin(e * 0.4 + fc.y);
			if (fc.x < 0.0) {
				yaw = yaw + K_PI;
			}
		}
		let R = sr_yaw(yaw);
		g_fish = fa;
		g_fph = fc.y * 3.0;
		let side = 0.5 * fa.w + 0.2 * L;
		sr_try(1, (ro - pos) * R, rd * R, R, vec3<f32>(-0.82 * L, -0.75 * fa.z, -side), vec3<f32>(0.5 * L, 0.75 * fa.z, side), 40, 0.7);
	}
	// The turtle, crossing slowly.
	{
		let z = -1.3;
		let pos = vec3<f32>(sr_cross(0.62, 0.14, -1.0, z, 1.0, aspect, e), 1.0 + 0.14 * sin(e * 0.3), z);
		let R = sr_yaw(K_PI + 0.1 * sin(e * 0.23));
		sr_try(2, (ro - pos) * R, rd * R, R, vec3<f32>(-0.5, -0.5, -0.8), vec3<f32>(0.6, 0.5, 0.8), 40, 0.8);
	}
	// The manta, far off and high.
	{
		let z = -3.9;
		let pos = vec3<f32>(sr_cross(0.2, 0.1, 1.0, z, 1.6, aspect, e), 1.55 + 0.15 * sin(e * 0.2), z);
		let R = sr_yaw(0.25 + 0.08 * sin(e * 0.17));
		sr_try(3, (ro - pos) * R, rd * R, R, vec3<f32>(-1.35, -0.65, -1.35), vec3<f32>(0.7, 0.65, 1.35), 40, 0.7);
	}
	// Jellyfish, rising.
	for (var i = 0; i < N_JELLY; i = i + 1) {
		let j = K_JELLY[i];
		let pulse = max(sin(e * 1.6 + j.w), 0.0);
		let pos = vec3<f32>(j.x + 0.15 * sin(e * 0.25 + j.w), -1.0 + fract(j.w * 0.37 + e * 0.016) * 4.2, j.y);
		g_jr = j.z;
		g_jp = pulse;
		g_jmat = 15 + i;
		let w = j.z * 1.2 + 0.2;
		sr_try(4, ro - pos, rd, ident, vec3<f32>(-w, -3.6 * j.z, -w), vec3<f32>(w, 1.25 * j.z, w), 36, 0.6);
	}
	// Kelp. (A strand's points, read once for the ray: its box first.)
	for (var s = 0; s < N_KELP; s = s + 1) {
		let lo = K_KELP_LO[s];
		let hi = K_KELP_HI[s];
		let ta = (lo - ro) / rd;
		let tb = (hi - ro) / rd;
		let tn = min(ta, tb);
		let tx = max(ta, tb);
		if (max(max(tn.x, tn.y), max(tn.z, 0.0)) < min(min(tx.x, tx.y), min(tx.z, g_best))) {
			for (var i = 0; i < 6; i = i + 1) {
				g_kp[i] = K_KELP[s * 6 + i];
			}
			sr_try(5, ro, rd, ident, lo, hi, 36, 0.75);
		}
	}
	// A school of small silver fish: each a splat of a body and a tail.
	{
		let z = -0.6;
		let cx = sr_cross(0.4, 0.42, -1.0, z, 1.4, aspect, e);
		let cy = 1.45 + 0.15 * sin(e * 0.3);
		for (var i = 0; i < 16; i = i + 1) {
			let fi = f32(i);
			let h = sr_h13(fi * 3.1 + 7.0);
			let c = vec3<f32>(cx + (h.x - 0.5) * 1.5 + 0.05 * sin(e * 1.1 + fi), cy + (h.y - 0.5) * 0.62 + 0.04 * cos(e * 0.9 + fi * 2.0), z + (h.z - 0.5) * 0.9);
			for (var k = 0; k < 2; k = k + 1) {
				var cc = c;
				var r = vec3<f32>(0.09, 0.036, 0.024);
				if (k == 1) {
					cc = c + vec3<f32>(0.11, 0.0, 0.03 * sin(e * 5.0 + fi * 2.3));
					r = vec3<f32>(0.035, 0.04, 0.012);
				}
				let oo = (ro - cc) / r;
				let dd = rd / r;
				let qa = dot(dd, dd);
				let qb = dot(oo, dd);
				let disc = qb * qb - qa * (dot(oo, oo) - 1.0);
				if (disc > 0.0) {
					let t = (-qb - sqrt(disc)) / qa;
					if (t > 0.0 && t < g_best) {
						g_best = t;
						g_id = 6;
						g_n = normalize((ro + rd * t - cc) / (r * r));
						g_ao = 1.0;
						g_m = 2;
						g_det = 0.42 - 0.3 * g_n.y;
					}
				}
			}
		}
	}

	// What the ray met, lit: a key light from the surface far above, then
	// the caustics playing over whatever faces up.
	let v = (cell.y + 0.5) / res.y;
	let wl = sr_water(v);
	var acc = vec3<f32>(0.0);
	var acc_a = 0.0;
	var rs = 10;
	var rc = N_PAL - 10;
	var lit_warm = false;
	let depth = g_best;
	if (depth < 1e3) {
		let p = ro + rd * depth;
		var l = 0.0;
		var m = 0;
		var ny = 0.0;
		var lw = 0.0;
		if (g_id >= 0) {
			let n = g_n;
			let ndl = dot(n, normalize(vec3<f32>(0.25, 0.75, 0.6)));
			l = 0.17 + 0.83 * clamp(ndl * 0.72 + 0.28, 0.0, 1.0);
			l = l * mix(0.35, 1.0, g_ao);
			l = l + (g_det - 0.5) * 0.42;
			m = g_m;
			ny = n.y;
		} else {
			l = st.x;
			m = i32(floor(st.y));
			ny = (fract(st.y) - 0.5) / 0.45;
			lw = st.w;
		}
		l = l + 0.06 * max(ny, 0.0) * sin(p.x * 8.0 + e * 1.2 + 2.0 * sin(p.z * 6.0 - e * 0.7));
		var col = sr_colour(m, l, e, p);
		rs = g_rs;
		rc = g_rc;
		lit_warm = lw > 0.03;
		col = col + vec3<f32>(0.9, 0.58, 0.3) * lw * (0.97 + 0.05 * sin(e * 1.7 + p.x * 3.0));
		// The water between: far things sink into its colour.
		var fogk = smoothstep(4.0, 11.5, depth) * 0.88;
		if (m == 10 || (m >= 15 && m <= 17)) {
			fogk = fogk * 0.4;
		}
		acc = mix(col, sr_ramp(0, 10, wl), fogk);
		acc_a = 1.0;
	}
	let sdepth = depth * dot(rd, g_fwd);

	// Light shafts: long faint splats, cut to dots.
	let c3 = cos(-0.3);
	let s3 = sin(-0.3);
	for (var i = 0; i < N_SHAFT; i = i + 1) {
		let s = K_SHAFT[i];
		let fi = f32(i);
		let c = vec3<f32>(s.x + 0.08 * sin(e * 0.2 + fi), 1.5, s.y);
		if (dot(c - ro, g_fwd) < sdepth) {
			let ext = vec3<f32>(s.z, 1.2, s.z) * 1.5;
			let o0 = ro - c;
			let oo = vec3<f32>(o0.x * c3 + o0.y * s3, -o0.x * s3 + o0.y * c3, o0.z) / ext;
			let dd = vec3<f32>(rd.x * c3 + rd.y * s3, -rd.x * s3 + rd.y * c3, rd.z) / ext;
			let qa = dot(dd, dd);
			let qb = dot(oo, dd);
			if (qb * qb - qa * (dot(oo, oo) - 1.0) > 0.0 && qb < 0.0) {
				let a = s.w * (0.55 + 0.45 * sin(e * 0.45 + fi * 2.1));
				acc = K_PAL[6] * a + acc * (1.0 - a);
				acc_a = a + acc_a * (1.0 - a);
			}
		}
	}
	// Each jellyfish's glow.
	for (var i = 0; i < N_JELLY; i = i + 1) {
		let j = K_JELLY[i];
		let c = vec3<f32>(j.x + 0.15 * sin(e * 0.25 + j.w), -1.0 + fract(j.w * 0.37 + e * 0.016) * 4.2, j.y);
		if (dot(c - ro, g_fwd) < sdepth + 0.3) {
			let oo = ro - c;
			let qb = dot(oo, rd);
			let rr = j.z * 1.9;
			if (qb * qb - (dot(oo, oo) - rr * rr) > 0.0 && qb < 0.0) {
				let a = 0.2 + 0.08 * sin(e * 1.6 + j.w);
				acc = sr_colour(15 + i, 0.45, e, c) * a + acc * (1.0 - a);
				acc_a = a + acc_a * (1.0 - a);
			}
		}
	}
	// Marine snow, sinking, and bubbles: a pixel each.
	let ppx = res.y / (2.0 * K_TAN);
	for (var i = 0; i < 130; i = i + 1) {
		let fi = f32(i);
		let b = sr_h13(fi * 1.7 + 11.0);
		let r = sr_h13(fi + 2.0);
		var p = vec3<f32>(-4.2 + b.x * 8.4, b.z * 3.6, -4.0 + b.y * 7.5);
		let yy = p.y - e * 0.03 * (0.4 + r.x);
		p.y = yy - 3.6 * floor(yy / 3.6) - 0.85;
		p.x = p.x + 0.06 * sin(e * 0.4 + r.y * 40.0);
		let vv = p - ro;
		let zc = dot(vv, g_fwd);
		if (zc < sdepth && zc > 0.3) {
			let sx = floor(res.x * 0.5 + dot(vv, g_right) / zc * ppx);
			let sy = floor(res.y * 0.5 - dot(vv, g_up) / zc * ppx);
			if (sx == cell.x && sy == cell.y) {
				let a = 0.9 * smoothstep(-0.85, -0.5, p.y) * (1.0 - smoothstep(2.3, 2.7, p.y)) * (0.4 + 0.6 * r.z);
				let c = K_PAL[5 + i32(floor(b.y * 2.99))];
				acc = c * a + acc * (1.0 - a);
				acc_a = a + acc_a * (1.0 - a);
			}
		}
	}
	for (var i = 0; i < 20; i = i + 1) {
		let fi = f32(i);
		let r = sr_h13(fi + 5.0);
		let cc = fract(e * 0.07 * (0.6 + r.x) + r.y);
		var p = K_VENT_A;
		if (i >= 10) {
			p = K_VENT_B;
		}
		p.y = p.y + cc * 3.0;
		p.x = p.x + 0.06 * sin(cc * 22.0 + r.z * 50.0) * cc;
		p.z = p.z + 0.06 * cos(cc * 17.0 + r.x * 50.0) * cc;
		let vv = p - ro;
		let zc = dot(vv, g_fwd);
		if (zc < sdepth && zc > 0.3) {
			let half = max(0.5, (0.012 + 0.014 * r.y) * (0.6 + cc) / zc * ppx);
			let dx = res.x * 0.5 + dot(vv, g_right) / zc * ppx - (cell.x + 0.5);
			let dy = res.y * 0.5 - dot(vv, g_up) / zc * ppx - (cell.y + 0.5);
			if (max(abs(dx), abs(dy)) <= half) {
				let a = 0.95 * smoothstep(0.0, 0.04, cc) * (1.0 - smoothstep(0.8, 1.0, cc));
				let c = K_PAL[7 + i32(floor(r.z * 1.99))];
				acc = c * a + acc * (1.0 - a);
				acc_a = a + acc_a * (1.0 - a);
			}
		}
	}

	// Hard pixels: there or not, by a Bayer threshold; then the nearest of
	// the palette's colours.
	if (acc_a > g_thr) {
		return vec4<f32>(sr_nearest(acc / max(acc_a, 1e-4), cell, pa.z, rs, rc, lit_warm), 1.0);
	}
	// Open water: the ramp's darkest few, dithered into each other.
	let wi = wl * 9.0;
	var idx = i32(floor(wi));
	if (fract(wi) > sr_bayer(cell)) {
		idx = idx + 1;
	}
	return vec4<f32>(K_PAL[idx], pc.x);
}
