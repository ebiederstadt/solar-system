shader_type spatial;

uniform sampler2D day_texture : source_color;
uniform sampler2D night_texture : source_color;
uniform sampler2D city_lights_texture : source_color;
uniform sampler2D normal_texture: hint_normal;

uniform vec3 sun_direction_world = vec3(1.0, 0.0, 0.0);
uniform float terminator_softness = 0.05;
uniform float city_light_strength = 2.0;
uniform float normal_strength = 1.0;

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndotl = -dot(world_normal, normalize(sun_direction_world));

	vec3 day_color = texture(day_texture, UV).rgb;
	vec3 night_color = texture(night_texture, UV).rgb;
	vec3 city_lights = texture(city_lights_texture, UV).rgb;
	
	float day_factor = smoothstep(-terminator_softness, terminator_softness, ndotl);
	float night_factor = 1.0 - day_factor;
	
	vec4 normal_tex = texture(normal_texture, UV);
	vec3 normal = vec3(normal_tex.xy * 2.0 - 1.0, 0.0);
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
	normal.xy *= normal_strength;
	
	ALBEDO = mix(night_color, day_color, day_factor);
	EMISSION = city_lights * night_factor * city_light_strength;
	NORMAL_MAP = normal * 0.5 + 0.5;
}