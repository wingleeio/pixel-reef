const K_TAN: f32 = 0.26794919;
const K_PI: f32 = 3.14159265;
const K_FLOOR: f32 = -0.75;

var<private> g_t: f32;
var<private> g_near: f32;
var<private> g_mat: i32;
var<private> g_thr: f32;
var<private> g_ro: vec3<f32>;
var<private> g_rd: vec3<f32>;
var<private> g_fwd: vec3<f32>;
var<private> g_right: vec3<f32>;
var<private> g_up: vec3<f32>;

/*TABLES*/

// ---- hashes and noise ------------------------------------------------------

fn sr_h31(p: vec3<f32>) -> f32 {
	var q = fract(p * vec3<f32>(0.1031, 0.1030, 0.0973));
	q = q + dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

fn sr_h13(x: f32) -> vec3<f32> {
	var p = fract(vec3<f32>(x) * vec3<f32>(0.1031, 0.1030, 0.0973));
	p = p + dot(p, p.yzx + 33.33);
	return fract((p.xxy + p.yzz) * p.zyx);
}

fn sr_noise(p: vec3<f32>) -> f32 {
	let i = floor(p);
	let f = fract(p);
	let u = f * f * (3.0 - 2.0 * f);
	let a = mix(sr_h31(i), sr_h31(i + vec3<f32>(1.0, 0.0, 0.0)), u.x);
	let b = mix(sr_h31(i + vec3<f32>(0.0, 1.0, 0.0)), sr_h31(i + vec3<f32>(1.0, 1.0, 0.0)), u.x);
	let c = mix(sr_h31(i + vec3<f32>(0.0, 0.0, 1.0)), sr_h31(i + vec3<f32>(1.0, 0.0, 1.0)), u.x);
	let d = mix(sr_h31(i + vec3<f32>(0.0, 1.0, 1.0)), sr_h31(i + vec3<f32>(1.0, 1.0, 1.0)), u.x);
	return mix(mix(a, b, u.y), mix(c, d, u.y), u.z);
}

// Cells: (distance to the nearest point, gap to the second nearest).
fn sr_cells(p: vec3<f32>, seed: f32) -> vec2<f32> {
	let ip = floor(p);
	var f1 = 9.0;
	var f2 = 9.0;
	for (var z = -1; z <= 1; z = z + 1) {
		for (var y = -1; y <= 1; y = y + 1) {
			for (var x = -1; x <= 1; x = x + 1) {
				let c = ip + vec3<f32>(f32(x), f32(y), f32(z));
				let o = vec3<f32>(sr_h31(c + seed), sr_h31(c.yzx + seed + 17.0), sr_h31(c.zxy + seed + 31.0));
				let d = length(p - (c + o));
				if (d < f1) {
					f2 = f1;
					f1 = d;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec2<f32>(f1, f2 - f1);
}

const K_BAYER: array<f32, 16> = array<f32, 16>(0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
fn sr_bayer(c: vec2<f32>) -> f32 {
	let x = u32(abs(c.x)) & 3u;
	let y = u32(abs(c.y)) & 3u;
	return (K_BAYER[y * 4u + x] + 0.5) / 16.0;
}

// ---- shapes ----------------------------------------------------------------

fn sd_ell(p: vec3<f32>, c: vec3<f32>, r: vec3<f32>) -> f32 {
	let q = p - c;
	let k0 = length(q / r);
	let k1 = length(q / (r * r));
	if (k1 < 1e-9) {
		return -min(r.x, min(r.y, r.z));
	}
	return k0 * (k0 - 1.0) / k1;
}

fn sd_cap(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, ra: f32, rb: f32) -> f32 {
	let ab = b - a;
	let ap = p - a;
	let h = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
	return length(ap - ab * h) - (ra + (rb - ra) * h);
}

fn sr_smin(a: f32, b: f32, k: f32) -> f32 {
	let h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}

// A fin's rays, as a ripple across it.
fn sr_rays(x: f32, y: f32, n: f32) -> f32 {
	return 0.005 * sin(atan2(y, x) * n);
}

// ---- the camera: still, looking across the reef ----------------------------

fn sr_camera(cell: vec2<f32>, res: vec2<f32>, pb: vec4<f32>) {
	let aspect = res.x / max(res.y, 1.0);
	let dist = 6.4 * max(pb.z, 0.2) * max(1.0, 1.25 / aspect);
	g_ro = vec3<f32>(0.0, 0.6, dist);
	let tgt = vec3<f32>(0.0, 0.45 + pb.w, 0.0);
	g_fwd = normalize(tgt - g_ro);
	g_right = normalize(cross(g_fwd, vec3<f32>(0.0, 1.0, 0.0)));
	g_up = cross(g_right, g_fwd);
	let ndc = vec2<f32>((cell.x + 0.5) / res.x * 2.0 - 1.0, 1.0 - (cell.y + 0.5) / res.y * 2.0);
	g_rd = normalize(g_fwd + g_right * (ndc.x * aspect * K_TAN) + g_up * (ndc.y * K_TAN));
}

fn sr_floor_y(x: f32, z: f32) -> f32 {
	return K_FLOOR + 0.08 * sin(0.9 * x + 1.0) * sin(0.7 * z + 0.5);
}
