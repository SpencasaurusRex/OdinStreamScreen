package main

import "core:mem"
import "core:fmt"

import gl "shared:odin-gl"
import glfw "shared:odin-glfw"
import bind "shared:odin-glfw/bindings"
import imgui "shared:odin-imgui"

// import "shared:odin-al/al"
// import "shared:odin-al/alc"

import "stbi"

// @cleanup globals
running := true;
fullscreen := true;

Pixel :: struct {
    r, g, b, a: f32
};

V3 :: struct #packed {
    x, y, z: f32
};

main :: proc() {
    using glfw;

    if !init() {
        return;
    }

    fmt.println("Loading file");

    x, y, channels: i32;
    raw_image_data := stbi.loadf("Text.png", &x, &y, &channels, 4);
    pixel_count := cast(int)(x * y);

    image_data := mem.slice_ptr(cast(^Pixel)raw_image_data, pixel_count);

    particle_count := 0;
    for pixel in image_data {
        if pixel.r == 1 && pixel.g == 1 && pixel.b == 1 {
            particle_count += 1;
        }
    }
    fmt.println("Particles:", particle_count);

    window := create_window(1300, 760, "Sandbox", nil, nil);
    if window == nil {
        terminate();
        return;
    }

    make_context_current(window);
    glfw.set_key_callback(window, key_callback);
    glfw.set_framebuffer_size_callback(window, size_callback);

    gl.load_up_to(4, 5, proc(p: rawptr, name: cstring) do (cast(^rawptr)p)^ = get_proc_address(name) );
    fmt.printf("Loaded OpenGL %d.%d\n", gl.loaded_up_to_major, gl.loaded_up_to_minor);
   
    shader_program,ok := gl.load_shaders_file("vertex.glsl", "fragment.glsl");

    vertices: []V3 = {
        V3 { -0.5, -1.0, 0 },
        V3 {  0.5, -1.0, 0 },
        V3 {  0.0,  0.0, 0 },
        V3 { -0.5,  0.0, 0 },
        V3 {  0.5,  0.0, 0 },
        V3 {  0.0,  1.0, 0 }
    };

    vbo: u32;
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    gl.GenBuffers(1, &vbo);

    gl.BindVertexArray(vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
            gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(V3), raw_data(vertices), gl.STATIC_DRAW);
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, nil);
            gl.EnableVertexAttribArray(0);
        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    for running && !window_should_close(window) {
        if key_pressed {
            fmt.println(key_code);
            key_pressed = false;
        }

        if get_key(window, .KEY_ESCAPE) == .PRESS {
            running = false;
        }

        gl.ClearColor(0, 0, 0, 0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.UseProgram(shader_program);
        gl.BindVertexArray(vao);

        gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)len(vertices));
        gl.BindVertexArray(0);

        swap_buffers(window);
        poll_events();
    }

    // @cleanup Is this really needed?
    terminate();
}

key_pressed := false;
key_code: i32;

key_callback :: proc "c" (window: glfw.Window_Handle, key, scancode, action, mods: i32) {
    if action == (bind.PRESS) && bind.GetKey(window, key) == bind.RELEASE {
        key_pressed = true;
        key_code = key;
    }
}

size_callback :: proc "c" (window: glfw.Window_Handle, width, height: i32) {
    gl.Viewport(0, 0, width, height);
}