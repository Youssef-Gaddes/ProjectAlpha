shader_type canvas_item;

uniform float fade_start : hint_range(0.0, 1.0) = 0.0;
uniform float fade_end : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    // Calculate transparency based on the horizontal (X) UV coordinate
    float alpha = smoothstep(fade_start, fade_end, UV.x);
    COLOR = vec4(color.rgb, color.a * alpha);
}
