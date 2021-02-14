package main

import "core:mem"
import "core:fmt"
import "core:math"
import "core:sort"
import "core:slice"
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

V3 :: distinct [3]f32;

Polar :: struct {
    r, d: f32
};

Particle :: struct {
    configuration: int,
    index: int,
    position: V3,
    offset: f32,
    velocity: V3
};

main :: proc() {
    using glfw;

    if !init() {
        return;
    }

    scaling :: 1.25;
    particle_mult :: 2;

    width, height, channels: i32;
    raw_image_data := stbi.loadf("BalancedCircle.png", &width, &height, &channels, 4);
    pixel_count := cast(int)(width * height);

    image_data := mem.slice_ptr(cast(^Pixel)raw_image_data, pixel_count);

    vertices := make([dynamic]V3);

    aspect := f32(width) / f32(height);
    dx :=  2.0 / f32(width);
    dy :=  2.0 / f32(height);

    configuration_0 := make([dynamic]Polar);
    configuration_1 := make([dynamic]Polar);

    particle_count := 0;
    for y in 0..<height {
        for x in 0..<width {
            pixel := image_data[y * width + x];
            if pixel.r + pixel.g + pixel.b > 0.19 {
                gl_x := (dx * f32(x) - 1) * aspect;
                gl_y := 1 - dy * f32(y);

                d := math.sqrt(gl_x * gl_x + gl_y * gl_y);
                p := Polar {math.atan2_f32(gl_y, gl_x), d};

                if gl_y > 0 {
                    append(&configuration_0, p);
                }
                else {
                    append(&configuration_1, p);
                }

                for j in 1..particle_mult {
                    append(&vertices, V3{ gl_x,                gl_y               , 0 });
                    append(&vertices, V3{ gl_x + dx * scaling, gl_y               , 0 });
                    append(&vertices, V3{ gl_x + dx * scaling, gl_y + dy * scaling, 0 });

                    append(&vertices, V3{ gl_x + dx * scaling, gl_y + dy * scaling, 0 });
                    append(&vertices, V3{ gl_x               , gl_y + dy * scaling, 0 });
                    append(&vertices, V3{ gl_x               , gl_y               , 0 });
                }

                particle_count += 1;
            }
        }    
    }

    slice.sort_by(configuration_0[:], proc(i, j: Polar) -> bool {return i.r < j.r});
    slice.sort_by(configuration_1[:], proc(i, j: Polar) -> bool {return i.r < j.r});

    particles := make([]Particle, particle_count * particle_mult);
    p := 0;

    a := 0;
    for i in 0..<len(configuration_0) {
        for j in 1..particle_mult {
            c := configuration_0[i];
            particles[p].position = polar_to_cartesian(c.r, c.d);
            particles[p].index = i;
            particles[p].configuration = 0;
            p += 1;
        }
    }
    for i in 0..<len(configuration_1) {
        for j in 1..particle_mult {
            c := configuration_1[i];
            particles[p].position = polar_to_cartesian(c.r, c.d);
            particles[p].index = i;
            particles[p].configuration = 1;
            p += 1;
        }
    }

    window := create_window(int(width * 2), int(height * 2), "Sandbox", nil, nil);
    if window == nil {
        terminate();
        return;
    }

    make_context_current(window);
    glfw.set_key_callback(window, key_callback);
    glfw.set_framebuffer_size_callback(window, size_callback);

    gl.load_up_to(4, 5, proc(p: rawptr, name: cstring) do (cast(^rawptr)p)^ = get_proc_address(name) );
   
    shader_program,ok := gl.load_shaders_file("vertex.glsl", "fragment.glsl");

    vbo: u32;
    gl.GenBuffers(1, &vbo);
    offset: f32 = 0;

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

        delta: f32 = .005;

        for i in 0..<len(particles) {
            particles[i].offset += delta;
            c: Polar;
            r: f32;
            if particles[i].configuration == 0 {
                index := min(len(configuration_0) - 1, particles[i].index);
                c = configuration_0[index];
                r = particles[i].offset + c.r;
                if r > math.PI {
                    particles[i].velocity += rand_unit_circle() * .005;
                    particles[i].configuration = 1;
                    particles[i].offset += math.PI;
                    for particles[i].offset > 0 {
                        particles[i].offset -= math.TAU;
                    }
                }
            }
            else {
                index := min(len(configuration_1) - 1, particles[i].index);
                c = configuration_1[index];
                r = particles[i].offset + c.r;
                if r > 0 {
                    particles[i].velocity += rand_unit_circle() * .005;
                    particles[i].configuration = 0;
                    particles[i].offset += math.PI;
                    for particles[i].offset > math.PI {
                        particles[i].offset -= math.TAU;
                    }
                }
            }

            target_position := polar_to_cartesian(r, c.d);
            target_position.x /= aspect;
            
            particles[i].velocity += (target_position - particles[i].position) * .005;
            particles[i].velocity *= 0.95; // Damping
            particles[i].position += particles[i].velocity;

            x := particles[i].position.x;
            xdx := x + dx * scaling;
            y := particles[i].position.y;
            ydy := y + dy * scaling;

            vertices[i*6+0].x = x;
            vertices[i*6+0].y = y;
            
            vertices[i*6+1].x = xdx;
            vertices[i*6+1].y = y;
            
            vertices[i*6+2].x = xdx;
            vertices[i*6+2].y = ydy;
            
            vertices[i*6+3].x = xdx;
            vertices[i*6+3].y = ydy;
            
            vertices[i*6+4].x = x;
            vertices[i*6+4].y = ydy;
            
            vertices[i*6+5].x = x;
            vertices[i*6+5].y = y;
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

lerp :: inline proc(a, b: $T, t: f32) -> T {
    return a + (b-a) * t;
}

inverse_lerp :: inline proc(a: f32, b: f32, v: f32) -> f32 {
    return (v - a) / (b - a);
}

remap :: inline proc(from_a: f32, from_b: f32, to_a: f32, to_b: f32, val: f32) -> f32 {
    return lerp(to_a, to_b, inverse_lerp(from_a, from_b, val));
}

rand_unit_circle :: proc() -> V3 {
    theta := rand.float32_range(0, math.TAU);
    return V3{math.cos_f32(theta), math.sin_f32(theta), 0};
}

polar_to_cartesian :: proc(r, d: f32) -> V3 {
    return V3{math.cos_f32(r) * d, math.sin_f32(r) * d, 0};
}