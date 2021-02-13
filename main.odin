package main

import "core:mem"
import "core:fmt"
import "core:math"
import rand "core:math/rand"

import gl "shared:odin-gl"
import glfw "shared:odin-glfw"
import bind "shared:odin-glfw/bindings"
import imgui "shared:odin-imgui"

import "stbi"

// TODO:
// Use indexed triangles via gl.DrawElements()
// Use MVP matrices


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

    width, height, channels: i32;
    raw_image_data := stbi.loadf("Text.png", &width, &height, &channels, 4);
    pixel_count := cast(int)(width * height);

    image_data := mem.slice_ptr(cast(^Pixel)raw_image_data, pixel_count);

    vertices := make([dynamic]V3);

    dx :=  2.0 / f32(width);
    dy :=  2.0 / f32(height);

    particle_count := 0;
    for y in 0..<height {
        for x in 0..<width {
            pixel := image_data[y * width + x];
            if pixel.r + pixel.g + pixel.b > 0.19 {
                gl_x := dx * f32(x) - 1;
                gl_y := 1 - dy * f32(y);
                append(&vertices, V3{ x=gl_x,      y=gl_y      });
                append(&vertices, V3{ x=gl_x + dx, y=gl_y      });
                append(&vertices, V3{ x=gl_x + dx, y=gl_y + dy });

                append(&vertices, V3{ x=gl_x + dx, y=gl_y + dy });
                append(&vertices, V3{ x=gl_x     , y=gl_y + dy });
                append(&vertices, V3{ x=gl_x     , y=gl_y      });

                particle_count += 1;
            }
        }    
    }

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

    vbo: u32;
    gl.GenBuffers(1, &vbo);

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
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
            gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(V3), raw_data(vertices), gl.STATIC_DRAW);
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, nil);
            gl.EnableVertexAttribArray(0);
            gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)len(vertices));
        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        // gl.BindVertexArray(0);

        i := 0;
        for i < len(vertices) {
            v := vertices[i];
            x := remap(-1, 1, 0, f32(width) , v.x);
            y := remap(-1, 1, 0, f32(height), v.y);

            fx, fy := rand_unit_circle();

            for j in 0..<6 {
                vertices[i+j].x += fx / 1000;
                vertices[i+j].y += fy / 1000;
            }

            i += 6;
        }

        swap_buffers(window);
        poll_events();
    }
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

lerp :: inline proc(a: f32, b: f32, t: f32) -> f32 {
    return a + (b-a) * t;
}

inverse_lerp :: inline proc(a: f32, b: f32, v: f32) -> f32 {
    return (v - a) / (b - a);
}

remap :: inline proc(from_a: f32, from_b: f32, to_a: f32, to_b: f32, val: f32) -> f32 {
    return lerp(to_a, to_b, inverse_lerp(from_a, from_b, val));
}

rand_unit_circle :: proc() -> (f32, f32) {
    theta := rand.float32_range(0, math.TAU);
    return math.cos_f32(theta), math.sin_f32(theta);
}