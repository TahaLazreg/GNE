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
const Physics = @import("./physics.zig");

const w_width = 640;
const w_height = 360;
const nbClouds = 5;
const nbObstacles = 2;

// Global timer for top right & obstacle speed
var timer: f32 = 0;

var gen = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gen.allocator();

pub fn main() !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const window: *sf.RenderWindow = try allocator.create(sf.RenderWindow);
    window.* = try sf.RenderWindow.createDefault(.{ .x = w_width, .y = w_height }, "Mousse's Great Adventure - Run!");
    defer {
        window.*.destroy();
        allocator.destroy(window);
    }

    // Physics accumulator
    var accumulator: f32 = 0;

    // Ground
    var ground = try sf.RectangleShape.create(.{ .x = w_width, .y = w_height / 3 });
    defer ground.destroy();
    ground.setFillColor(sf.Color.fromRGB(201, 130, 58));
    ground.setPosition(.{ .x = 0, .y = w_height * (2.0 / 3.0) + 20 });

    // Text for clock
    const font: sf.Font = try sf.Font.createFromFile("Assets/8BitLimitBrk-xOOj.ttf");
    var timerText: sf.Text = try sf.Text.createWithText("0.0", font, 16);
    timerText.setPosition(.{ .x = w_width - 60, .y = 0 });
    timerText.setFillColor(sf.Color.Black);

    var clock = try sf.Clock.create();
    defer clock.destroy();

    const player: *Cat = try Cat.create(w_width, w_height, allocator, rand);
    defer {
        player.*.destroy();
        allocator.destroy(player);
    }

    // Create clouds
    var cloud: [nbClouds]ScrollEntity = undefined;
    var i: u8 = 0;
    while (i < nbClouds) : (i += 1) {
        cloud[i] = try ScrollEntity.createSkyDec(w_width, w_height, "./Assets/Cloud.png", -30, false, rand);
    }
    defer {
        i = 0;
        while (i < nbClouds) : (i += 1) {
            cloud[i].destroy();
        }
    }

    var obstacles: [nbObstacles]ScrollEntity = undefined;
    i = 0;
    while (i < nbObstacles) : (i += 1) {
        obstacles[i] = try ScrollEntity.createObstacle(w_width, w_height, 10, "./Assets/Cloud.png", 0, true, rand);
    }

    while (window.*.isOpen()) {
        const dt = clock.restart().asSeconds();
        accumulator += dt;
        timer += dt;

        // Input
        while (window.*.pollEvent()) |event| {
            switch (event) {
                .closed => window.*.close(),
                .keyPressed => |key| {
                    if (key.code == sf.keyboard.KeyCode.Space) {
                        player.*.jump();
                    }
                },
                else => {},
            }
        }

        // Slice shenanigans + formatting float
        var string_holder: [64]u8 = undefined;
        const str_slice = string_holder[0..];
        const textSlice = try std.fmt.formatFloat(str_slice, timer * 10, .{ .mode = .decimal, .precision = 0 });
        var nulltermString: [10:0]u8 = undefined;

        for (textSlice, 0..) |char, idx| {
            nulltermString[idx] = char;
        }
        nulltermString[textSlice.len] = 0;
        timerText.setString(nulltermString[0..textSlice.len :0]);

        Physics.physicsUpdate(&accumulator, player, &obstacles, &cloud, &timer, nbClouds, w_width, w_height);
        renderUpdate(window, dt, player, &obstacles, &cloud);
        drawState(window, player, &obstacles, &cloud, ground, timerText);
    }
}

pub fn renderUpdate(window: *sf.RenderWindow, dt: f32, player: *Cat, obstacles: []ScrollEntity, cloud: []ScrollEntity) void {
    // Render update
    var i: u8 = 0;
    if (!player.*.render_update(dt)) {
        window.*.close();
    }

    i = 0;
    while (i < nbObstacles) : (i += 1) {
        if (!obstacles[i].render_update(dt)) {
            window.*.close();
        }
    }

    i = 0;
    while (i < nbClouds) : (i += 1) {
        if (!cloud[i].render_update(dt)) {
            window.*.close();
        }
    }
}

pub fn drawState(window: *sf.RenderWindow, player: *Cat, obstacles: []ScrollEntity, cloud: []ScrollEntity, ground: sf.RectangleShape, timerText: sf.Text) void {
    // Draw
    window.*.clear(sf.Color.Cyan);

    var i: u8 = 0;
    while (i < nbClouds) : (i += 1) {
        window.*.draw(cloud[i].sprite, null);
    }
    window.*.draw(player.*.sprite, null);

    i = 0;
    while (i < nbObstacles) : (i += 1) {
        window.*.draw(obstacles[i].sprite, null);
    }

    window.*.draw(ground, null);
    window.*.draw(timerText, null);
    window.*.display();
}

fn leftPad(input: []u8, totalLen: u8) []u8 {
    var charsToCopy: u8 = 0;
    for (input) |char| {
        if (char == '.') {
            break;
        }
        charsToCopy += 1;
    }

    var i: u8 = 0;
    var strPadded: [10:0]u8 = undefined;
    while (i < totalLen) {
        strPadded = if (i < totalLen - charsToCopy) '0' else input[i - (totalLen - charsToCopy)];
        i += 1;
    }

    return strPadded;
}
