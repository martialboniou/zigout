//
// code by tsoding + refactoring by hondana (runs on zig 0.12)
//
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const overlaps = c.SDL_HasIntersection;

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));
const INITIAL_BAR_X: f32 = WINDOW_WIDTH / 2 - BAR_LEN / 2;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const BACKGROUND_COLOR = 0xFF181818;
const PROJ_SIZE: f32 = 25;
const PROJ_SPEED: f32 = 500;
const PROJ_COLOR = 0xFFFFFFFF;
const BAR_LEN: f32 = 100;
const BAR_THICKNESS: f32 = PROJ_SIZE;
const BAR_Y: f32 = WINDOW_HEIGHT - PROJ_SIZE - 50;
const BAR_SPEED: f32 = PROJ_SPEED;
const BAR_COLOR = 0xFF3030FF;
const TARGET_WIDTH = BAR_LEN;
const TARGET_HEIGHT = BAR_THICKNESS;
const TARGET_PADDING_X: f32 = 20;
const TARGET_PADDING_Y: f32 = 50;
const TARGET_ROWS = 4;
const TARGET_COLS = 5;
const TARGET_GRID_WIDTH = (TARGET_COLS * TARGET_WIDTH + (TARGET_COLS - 1) * TARGET_PADDING_X);
const TARGET_GRID_X: f32 = WINDOW_WIDTH / 2 - TARGET_GRID_WIDTH / 2;
const TARGET_GRID_Y: f32 = 50;
const TARGET_COLOR = 0xFF30FF30;

const Target = struct {
    x: f32,
    y: f32,
    dead: bool = false,
};

fn init_targets() [TARGET_ROWS * TARGET_COLS]Target {
    var targets: [TARGET_ROWS * TARGET_COLS]Target = undefined;
    var row = 0;
    while (row < TARGET_ROWS) : (row += 1) {
        var col = 0;
        while (col < TARGET_COLS) : (col += 1) {
            targets[row * TARGET_COLS + col] = Target{
                .x = TARGET_GRID_X + (TARGET_WIDTH + TARGET_PADDING_X) * @as(f32, @floatFromInt(col)),
                .y = TARGET_GRID_Y + TARGET_PADDING_Y * @as(f32, @floatFromInt(row)),
            };
        }
    }
    return targets;
}

var targets_pool = init_targets();
var bar_x = WINDOW_WIDTH / 2 - BAR_LEN / 2;
var bar_dx: f32 = 0;
var proj_x: f32 = WINDOW_WIDTH / 2 - PROJ_SIZE / 2;
var proj_y = @as(f32, BAR_Y - BAR_THICKNESS / 2 - PROJ_SIZE); // same as proj_x
var proj_dx: f32 = 1;
var proj_dy: f32 = 1;
var quit = false;
var pause = false;
var started = false;
// TODO: death
// TODO: score
// TODO: victory

fn make_rect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect{
        .x = @as(i32, @intFromFloat(x)),
        .y = @as(i32, @intFromFloat(y)),
        .w = @as(i32, @intFromFloat(w)),
        .h = @as(i32, @intFromFloat(h)),
    };
}

fn set_color(renderer: *c.SDL_Renderer, color: u32) void {
    const r: u8 = @truncate((color >> (0 * 8)) & 0xff);
    const g: u8 = @truncate((color >> (1 * 8)) & 0xff);
    const b: u8 = @truncate((color >> (2 * 8)) & 0xff);
    const a: u8 = @truncate((color >> (3 * 8)) & 0xff);
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

fn target_rect(target: *const Target) c.SDL_Rect {
    return make_rect(target.x, target.y, TARGET_WIDTH, TARGET_HEIGHT);
}

fn proj_rect(x: f32, y: f32) c.SDL_Rect {
    return make_rect(x, y, PROJ_SIZE, PROJ_SIZE);
}

fn bar_rect(x: f32) c.SDL_Rect {
    return make_rect(x, BAR_Y - BAR_THICKNESS / 2, BAR_LEN, BAR_THICKNESS);
}

fn horz_collision(dt: f32) void {
    var proj_nx: f32 = proj_x + proj_dx * PROJ_SPEED * dt;
    if (proj_nx < 0 or proj_nx + PROJ_SIZE > WINDOW_WIDTH or overlaps(&proj_rect(proj_nx, proj_y), &bar_rect(bar_x)) != 0) {
        proj_dx *= -1;
        return;
    }
    for (targets_pool[0..]) |*target_ptr| { // or &targets_pool, see vert_collision
        if (!target_ptr.dead and overlaps(&proj_rect(proj_nx, proj_y), &target_rect(target_ptr)) != 0) {
            target_ptr.dead = true;
            proj_dx *= -1;
            return;
        }
    }
    proj_x = proj_nx;
}

fn vert_collision(dt: f32) void {
    var proj_ny: f32 = proj_y + proj_dy * PROJ_SPEED * dt;
    if (proj_ny < 0 or proj_ny + PROJ_SIZE > WINDOW_HEIGHT) {
        proj_dy *= -1;
        return;
    }
    if (overlaps(&proj_rect(proj_x, proj_ny), &bar_rect(bar_x)) != 0) {
        if (bar_dx != 0) proj_dx = bar_dx;
        proj_dy *= -1;
        return;
    }
    for (&targets_pool) |*target_ptr| {
        if (!target_ptr.dead and overlaps(&proj_rect(proj_x, proj_ny), &target_rect(target_ptr)) != 0) {
            target_ptr.dead = true;
            proj_dy *= -1;
            return;
        }
    }
    proj_y = proj_ny;
}

fn bar_collision(dt: f32) void {
    var bar_nx: f32 = std.math.clamp(bar_x + bar_dx * BAR_SPEED * dt, 0, WINDOW_WIDTH - BAR_LEN);
    if (overlaps(&proj_rect(proj_x, proj_y), &bar_rect(bar_nx)) != 0) return;
    bar_x = bar_nx;
}

fn update(dt: f32) void {
    if (!pause and started) {
        if (overlaps(&proj_rect(proj_x, proj_y), &bar_rect(bar_x)) != 0) {
            proj_y = BAR_Y - BAR_THICKNESS / 2 - PROJ_SIZE - 1.0;
            return;
        }
        bar_collision(dt);
        horz_collision(dt);
        vert_collision(dt);
    }
}

fn render(renderer: *c.SDL_Renderer) void {
    set_color(renderer, PROJ_COLOR);
    _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);
    _ = c.SDL_RenderFillRect(renderer, &proj_rect(proj_x, proj_y));

    _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0, 0, 0xff);
    _ = c.SDL_RenderFillRect(renderer, &bar_rect(bar_x));

    for (targets_pool) |target| {
        if (!target.dead) {
            _ = c.SDL_SetRenderDrawColor(renderer, 0, 0xff, 0, 0xff);
            _ = c.SDL_RenderFillRect(renderer, &target_rect(&target));
        }
    }
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Zigout", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const keyboard = c.SDL_GetKeyboardState(null);

    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    ' ' => {
                        pause = !pause;
                    },
                    else => {},
                },
                else => {},
            }
        }

        bar_dx = 0;
        if (keyboard[c.SDL_SCANCODE_LEFT] != 0) {
            bar_dx += -1;
            if (!started) {
                started = true;
                proj_dx = -1;
            }
        } else if (keyboard[c.SDL_SCANCODE_RIGHT] != 0) {
            bar_dx += 1;
            if (!started) {
                started = true;
                proj_dx = 1;
            }
        }

        update(DELTA_TIME_SEC);

        _ = c.SDL_SetRenderDrawColor(renderer, 0x18, 0x18, 0x18, 0xff);
        _ = c.SDL_RenderClear(renderer);

        render(renderer);

        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(1000 / FPS);
    }
}
