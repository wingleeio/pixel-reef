// ---- the still scenery: sand, boulders, corals. Drawn once, and kept as
// (light, material + how far up its normal points, depth, warm light). ---------

var<private> g_kind: i32;
var<private> g_fanc: vec3<f32>;

fn sr_ground(p: vec3<f32>) -> f32 {
	var mat = 1;
	var kind = 1;
	// The sand.
	var d = p.y - sr_floor_y(p.x, p.z);
	if (d < g_near + 0.1) {
		d = d - 0.014 * sr_noise(p * 7.0);
	}
	// Boulders, roughened, settled into each other and the sand.
	var dr = 1e9;
	for (var i = 0; i < N_ROCK; i = i + 1) {
		let c = K_ROCK_C[i];
		let r = K_ROCK_R[i];
		let bd = length(p - c) - max(r.x, max(r.y, r.z));
		if (bd > g_near + 0.15) {
			dr = min(dr, bd);
		} else {
			dr = sr_smin(dr, sd_ell(p, c, r), 0.1);
		}
	}
	if (dr < g_near + 0.2) {
		dr = dr - 0.07 * sr_noise(p * 3.5) - 0.028 * sr_noise(p * 10.0);
	} else {
		dr = dr - 0.1;
	}
	if (dr < d) {
		mat = 0;
		kind = 0;
	}
	d = sr_smin(d, dr, 0.12);

	// Branching corals.
	for (var c = 0; c < N_CORAL; c = c + 1) {
		let bc = K_CORAL[c];
		let bd = length(p - bc.xyz) - bc.w;
		if (bd > g_near) {
			d = min(d, bd);
			continue;
		}
		var dc = 1e9;
		for (var j = 0; j < 12; j = j + 1) {
			let a = K_BR_A[c * 12 + j];
			let b = K_BR_B[c * 12 + j];
			dc = sr_smin(dc, sd_cap(p, a.xyz, b.xyz, a.w, b.w), 0.02);
		}
		if (dc < d) {
			d = dc;
			kind = 2;
			mat = 4;
			if (c == 1) {
				mat = 5;
			}
		}
	}
	// Brain corals.
	for (var i = 0; i < N_BRAIN; i = i + 1) {
		let s = K_BRAIN[i];
		let ds = sd_ell(p, s.xyz, vec3<f32>(s.w, s.w * 0.8, s.w));
		if (ds < d) {
			d = ds;
			kind = 3;
			mat = 3;
			if ((i & 1) == 1) {
				mat = 4;
			}
		}
	}
	// Tube sponges, hollow at the top.
	for (var i = 0; i < N_TUBE; i = i + 1) {
		let tb = K_TUBE[i];
		let top = tb.xyz + vec3<f32>(0.0, tb.w, 0.0);
		var dt = sd_cap(p, tb.xyz, top, 0.07, 0.06);
		dt = max(dt, -sd_cap(p, top - vec3<f32>(0.0, 0.1, 0.0), top + vec3<f32>(0.0, 0.1, 0.0), 0.038, 0.042));
		if (dt < d) {
			d = dt;
			kind = 4;
			mat = 5;
			if (i >= 3) {
				mat = 8;
			}
		}
	}
	// The anemone.
	let ba = length(p - K_AN_C) - 0.42;
	if (ba > g_near) {
		d = min(d, ba);
	} else {
		let dd = sd_ell(p, K_AN_C, vec3<f32>(0.15, 0.09, 0.15));
		if (dd < d) {
			d = dd;
			kind = 5;
			mat = 4;
		}
		var dn = 1e9;
		for (var i = 0; i < 16; i = i + 1) {
			dn = min(dn, sd_cap(p, K_AN_A[i], K_AN_B[i], 0.024, 0.016));
		}
		if (dn < d) {
			d = dn;
			kind = 6;
			mat = 18;
		}
	}
	// Sea fans.
	for (var i = 0; i < N_FAN; i = i + 1) {
		let f = K_FAN[i];
		let bd = length(p - f.xyz) - f.w - 0.2;
		if (bd > g_near) {
			d = min(d, bd);
			continue;
		}
		let q = p - f.xyz;
		let dish = vec3<f32>(q.x, q.y, q.z - 1.1 * (q.x * q.x + q.y * q.y) + 0.06);
		var df = (sd_ell(dish, vec3<f32>(0.0), vec3<f32>(f.w, f.w, 0.016)) + sr_rays(q.x, q.y + f.w, 26.0) * 1.6) * 0.6;
		df = max(df, -(q.y + f.w * 0.55));
		df = min(df, sd_cap(p, f.xyz - vec3<f32>(0.0, f.w + 0.22, 0.0), f.xyz - vec3<f32>(0.0, f.w - 0.06, 0.0), 0.024, 0.016));
		if (df < d) {
			d = df;
			kind = 7;
			g_fanc = f.xyz - vec3<f32>(0.0, f.w, 0.0);
			mat = 19;
			if (i == 1) {
				mat = 20;
			}
		}
	}
	// Glowing buds on short stalks.
	for (var i = 0; i < N_BUD; i = i + 1) {
		let b = K_BUD[i];
		let bd = length(p - b) - 0.16;
		if (bd > g_near) {
			d = min(d, bd);
			continue;
		}
		let s = sd_cap(p, b, b + vec3<f32>(0.0, 0.07, 0.0), 0.014, 0.01);
		if (s < d) {
			d = s;
			kind = 8;
			mat = 6;
		}
		let g = length(p - b - vec3<f32>(0.0, 0.09, 0.0)) - 0.03;
		if (g < d) {
			d = g;
			kind = 8;
			mat = 10;
		}
	}
	g_mat = mat;
	g_kind = kind;
	return d;
}

// Each surface's grain.
fn sr_grain(kind: i32, p: vec3<f32>) -> f32 {
	var a = 0.5;
	if (kind == 0) {
		let w = sr_cells(p * vec3<f32>(4.0, 5.5, 4.0), 8.0);
		a = 0.5 + 0.4 * (sr_noise(p * vec3<f32>(7.0, 12.0, 7.0)) - 0.5);
		if (w.y < 0.06) {
			a = a - 0.28;
		}
	} else if (kind == 1) {
		a = 0.5 + 0.13 * sin(p.x * 15.0 + 2.2 * sin(p.z * 5.0 + p.x * 1.3)) + 0.22 * (sr_noise(p * 16.0) - 0.5);
	} else if (kind == 2) {
		a = 0.5 + 0.3 * (sr_noise(p * 28.0) - 0.5);
	} else if (kind == 3) {
		a = 0.5 + 0.34 * sin(34.0 * sr_noise(p * 7.0));
	} else if (kind == 4) {
		let w = sr_cells(p * 24.0, 5.0);
		a = 0.56;
		if (w.x < 0.3) {
			a = 0.3;
		}
	} else if (kind == 5) {
		a = 0.42;
	} else if (kind == 6) {
		a = 0.3 + 2.6 * (p.y - K_AN_C.y);
	} else if (kind == 7) {
		let fv = p - g_fanc;
		a = 0.5 + 0.2 * sin(length(fv) * 60.0) + 0.24 * sin(atan2(fv.y, fv.x) * 26.0);
	}
	return clamp(a, 0.0, 1.0);
}

fn run(input: PassInput) -> vec4<f32> {
	let cell = floor(input.pixel);
	g_thr = sr_bayer(cell + 2.0) * 0.96 + 0.02;
	g_t = 0.0;
	sr_camera(cell, input.size, input.params[1]);
	let none = vec4<f32>(0.0, 0.0, 1e4, 0.0);

	g_near = 0.05;
	var t = 0.5;
	var hit = false;
	for (var i = 0; i < 120; i = i + 1) {
		let dist = sr_ground(g_ro + g_rd * t);
		if (dist < 0.003 + t * 0.0004) {
			hit = true;
			break;
		}
		t = t + dist * 0.8;
		if (t > 16.0) {
			break;
		}
	}
	if (!hit) {
		return none;
	}
	let p = g_ro + g_rd * t;
	g_near = 4.0;
	let d0 = sr_ground(p);
	let m = g_mat;
	let kind = g_kind;
	// Far off, the reef thins out to nothing, in dots.
	var there = 1.0 - smoothstep(8.5, 11.5, t);
	if (m != 1) {
		there = 1.0 - smoothstep(11.0, 14.0, t);
	}
	if (there <= g_thr) {
		return none;
	}
	let grain = sr_grain(kind, p);
	let k = vec2<f32>(1.0, -1.0) * 0.008;
	let n = normalize(k.xyy * sr_ground(p + k.xyy) + k.yyx * sr_ground(p + k.yyx) + k.yxy * sr_ground(p + k.yxy) + k.xxx * sr_ground(p + k.xxx));
	let h = 0.03;
	var occ = max(0.0, 1.0 - sr_ground(p + n * 2.0 * h) / (2.0 * h));
	occ = occ + max(0.0, 1.0 - sr_ground(p + n * 5.0 * h) / (5.0 * h));
	occ = occ + max(0.0, 1.0 - sr_ground(p + n * 10.0 * h) / (10.0 * h));
	let ao = max(0.0, 1.0 - occ / 2.2);

	// Key light from the surface, far above.
	let ndl = dot(n, normalize(vec3<f32>(0.25, 0.75, 0.6)));
	var l = 0.17 + 0.83 * clamp(ndl * 0.72 + 0.28, 0.0, 1.0);
	l = l * mix(0.35, 1.0, ao);
	l = l + (grain - 0.5) * 0.42;
	// Warm light pooling round the glowing buds.
	var lw = 0.0;
	if (m != 10) {
		for (var i = 0; i < N_BUD; i = i + 1) {
			let lv = K_BUD[i] + vec3<f32>(0.0, 0.09, 0.0) - p;
			let ld = max(length(lv), 1e-4);
			lw = lw + (max(dot(n, lv / ld), 0.0) * 0.85 + 0.1) / (1.0 + ld * ld * 34.0);
		}
	}
	return vec4<f32>(clamp(l, 0.0, 1.0), f32(m) + clamp(n.y * 0.45 + 0.5, 0.02, 0.98), t, lw);
}
