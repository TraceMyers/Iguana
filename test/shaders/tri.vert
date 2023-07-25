#version 450

layout(binding = 0) uniform fMVP {
    mat4 model;
    mat4 view;
    mat4 projection;
} mvp;

layout(location = 0) in vec2 in_position;
layout(location = 1) in vec3 in_color;
layout(location = 2) in vec2 tex_coord;

layout(location = 0) out vec3 frag_color;
layout(location = 1) out vec2 frag_tex_coord;

void main() {
    gl_Position = mvp.projection * mvp.view * mvp.model * vec4(in_position, 0.0, 1.0);
    frag_color = in_color;
    frag_tex_coord = tex_coord;
}