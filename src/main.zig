// const std = @import("std");

// pub fn main() !void {
//     // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
//     std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

//     // stdout is for the actual output of your application, for example if you
//     // are implementing gzip, then only the compressed bytes should be sent to
//     // stdout, not any debugging messages.
//     const stdout_file = std.io.getStdOut().writer();
//     var bw = std.io.bufferedWriter(stdout_file);
//     const stdout = bw.writer();

//     try stdout.print("Run `zig build test` to run the tests.\n", .{});

//     try bw.flush(); // don't forget to flush!
// }

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

//! This is a translation of the c++ code the sfml website gives you to test if SFML works
//! for instance, in this page: https://www.sfml-dev.org/tutorials/2.6/start-vc.php

const std = @import("std");
const print = std.debug.print;

const sf = struct {
    const sfml = @import("sfml");
    pub usingnamespace sfml;
    pub usingnamespace sfml.window;
    pub usingnamespace sfml.graphics;
    pub usingnamespace sfml.audio;
    pub usingnamespace sfml.system;
};

const Cat = @import("./cat.zig");
const ScrollEntity = @import("./scroll-entity.zig");

const w_width = 640;
const w_height = 360;
const phys_update: comptime_float = 1.0 / 60.0;

pub fn main() !void {
    var window = try sf.RenderWindow.createDefault(.{ .x = w_width, .y = w_height }, "Mousse's Great Adventure - Run!");
    defer window.destroy();

    // Physics accumulator
    var accumulator: f32 = 0;

    // Ground
    var ground = try sf.RectangleShape.create(.{ .x = w_width, .y = w_height / 3 });
    defer ground.destroy();
    ground.setFillColor(sf.Color.fromRGB(201, 130, 58));
    ground.setPosition(.{ .x = 0, .y = w_height * (2.0 / 3.0) + 20 });

    var cloud = try ScrollEntity.create(w_width, w_height, "./Assets/Cloud.png", -30, false);
    defer cloud.destroy();

    var clock = try sf.Clock.create();
    defer clock.destroy();

    var player = try Cat.create(w_width, w_height);
    defer player.destroy();

    while (window.isOpen()) {
        const dt = clock.restart().asSeconds();
        accumulator += dt;

        while (window.pollEvent()) |event| {
            switch (event) {
                .closed => window.close(),
                .keyPressed => |key| {
                    if (key.code == sf.keyboard.KeyCode.Space) {
                        player.jump();
                    }
                },
                else => {},
            }
        }

        while (accumulator >= phys_update) {
            _ = player.phys_update(phys_update);
            _ = cloud.phys_update(phys_update);
            accumulator -= phys_update;
        }

        if (!player.render_update(dt) or !cloud.render_update(dt)) {
            window.close();
        }

        window.clear(sf.Color.Cyan);
        window.draw(cloud.sprite, null);
        window.draw(player.sprite, null);
        window.draw(ground, null);
        window.display();
    }
}
