fn layer(input: LayerInput) -> vec4<f32> {
	let sz = zgx_reef_size();
	let uv = (floor(input.p / max(input.size, vec2<f32>(1.0)) * sz) + 0.5) / sz;
	let c = zgx_reef(uv);
	let pb = input.params[1];
	// Muted: every colour drawn a share of the way toward the deep water's.
	let quiet = mix(c.rgb, vec3<f32>(0.035, 0.075, 0.15), input.params[2].y);
	return vec4<f32>(quiet * pb.y, c.a * pb.x);
}
