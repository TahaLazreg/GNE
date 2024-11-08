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
const nbClouds = 5;
const nbObstacles = 16;
const broadphaseDivision = 3;

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

    var clock = try sf.Clock.create();
    defer clock.destroy();

    const player: *Cat = try Cat.create(w_width, w_height, allocator);
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
        obstacles[i] = try ScrollEntity.createObstacle(w_width, w_height, 10, "./Assets/Cloud.png", -100, true, rand);
    }

    while (window.*.isOpen()) {
        const dt = clock.restart().asSeconds();
        accumulator += dt;

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

        physicsUpdate(&accumulator, player, &obstacles, &cloud);
        renderUpdate(window, dt, player, &obstacles, &cloud);
        drawState(window, player, &obstacles, &cloud, ground);
    }
}

pub fn physicsUpdate(accumulator: *f32, player: *Cat, obstacles: []ScrollEntity, cloud: []ScrollEntity) void {
    // Physics update
    var i: u8 = 0;
    while (accumulator.* >= phys_update) {
        _ = player.*.phys_update(phys_update);

        while (i < nbObstacles) : (i += 1) {
            _ = obstacles[i].phys_update(phys_update);
        }

        i = 0;
        while (i < nbClouds) : (i += 1) {
            _ = cloud[i].phys_update(phys_update);
        }

        accumulator.* -= phys_update;
    }

    // Add collision checks
    var allObjects: [nbObstacles + 1]sf.RectangleShape = undefined;

    for (allObjects, 0..) |_, y| {
        if (y == obstacles.len) {
            allObjects[y] = player.hitBox;
        } else allObjects[y] = obstacles[y].hitBox;
    }

    //// Check positions of objects in the grid & create lists of objects per grid+
    i = 0;
    var objectsInQuadrants: [broadphaseDivision * broadphaseDivision][allObjects.len]?sf.RectangleShape = undefined;

    while (i < broadphaseDivision * broadphaseDivision) : (i += 1) {
        for (allObjects, 0..) |_, k| {
            objectsInQuadrants[i][k] = null;
        }
    }

    i = 0;
    var j: u8 = 0;
    while (i < broadphaseDivision) : (i += 1) {
        j = 0;
        while (j < broadphaseDivision) : (j += 1) {
            broadphase(&allObjects, i, j, &objectsInQuadrants[i * 3 + j]);
        }
    }

    //// Check collision of objects pairwise if they are in the same list
    i = 0;
    while (i < broadphaseDivision * broadphaseDivision) : (i += 1) {
        for (objectsInQuadrants[i]) |first| {
            if (first) |colliderOne|
                for (objectsInQuadrants[i]) |second| {
                    if (second) |colliderTwo| {
                        _ = colliderTwo.getLocalBounds();
                        _ = narrowphase(colliderOne, colliderTwo);
                    } else continue;
                } else continue;
        }
    }
}

pub fn broadphase(allObjects: []sf.RectangleShape, i: u8, j: u8, quad: *[nbObstacles + 1]?sf.RectangleShape) void {
    // Check all objects
    var nbObjInArr: u8 = 0;
    for (allObjects) |hitBox| {
        var k: u8 = 0;
        // For all points (idx k (u for fetch point)) in object
        while (k < 4) : (k += 1) {
            var point = hitBox.getGlobalBounds().getCorner();
            if (k % 2 == 1) {
                point = point.add(.{ .x = hitBox.getGlobalBounds().width, .y = 0 });
            }
            if (k >= 2) {
                point = point.add(.{ .x = 0, .y = hitBox.getGlobalBounds().height });
            }
            // If point in quad
            if (point.x < @as(f32, @floatFromInt(i + 1)) * (w_width / broadphaseDivision) and point.y < @as(f32, @floatFromInt(j + 1)) * (w_height / broadphaseDivision) and
                point.x >= @as(f32, @floatFromInt(i)) * (w_width / broadphaseDivision) and point.y >= @as(f32, @floatFromInt(j)) * (w_height / broadphaseDivision))
            {
                quad[nbObjInArr] = hitBox;
                nbObjInArr += 1;
                break;
            }
        }
    }
}

pub fn narrowphase(first: sf.RectangleShape, second: sf.RectangleShape) bool {
    var i: u2 = 0;
    var j: u2 = 0;
    var x1: ?f32 = null;
    var x2: ?f32 = null;
    var y1: ?f32 = null;
    var y2: ?f32 = null;

    while (j < 4) : (j += 1) {
        var point = second.getGlobalBounds().getCorner();
        if (j % 2 == 1) {
            point = point.add(.{ .x = second.getGlobalBounds().width, .y = 0 });
        }
        if (j >= 2) {
            point = point.add(.{ .x = 0, .y = second.getGlobalBounds().height });
        }
        if (x1) |_| {
            if (point.x != x1.?) {
                x2 = point.x;
            }
        } else {
            x1 = point.x;
        }

        if (y1) |_| {
            if (point.y != y1.?) {
                y2 = point.y;
            }
        } else {
            y1 = point.y;
        }

        if (x2 != null and y2 != null) break;
        if (j == 3) break;
    }

    while (i < 4) : (i += 1) {
        var point = first.getGlobalBounds().getCorner();
        if (i % 2 == 1) {
            point = point.add(.{ .x = first.getGlobalBounds().width, .y = 0 });
        }
        if (i >= 2) {
            point = point.add(.{ .x = 0, .y = first.getGlobalBounds().height });
        }
        if (((point.x <= x1.? and point.x >= x2.?) or (point.x <= x2.? and point.x >= x1.?)) and
            ((point.y <= y1.? and point.y >= y2.?) or (point.x <= y2.? and point.y >= y1.?)))
        {
            return true;
        }
        if (i == 3) break;
    }
    return false;
}

pub fn renderUpdate(window: *sf.RenderWindow, dt: f32, player: *Cat, obstacles: []ScrollEntity, cloud: []ScrollEntity) void {
    // Render update
    var i: u8 = 0;
    if (!player.*.render_update(dt)) {
        window.*.close();
    }

    i = 0;
    while (i < nbClouds) : (i += 1) {
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

pub fn drawState(window: *sf.RenderWindow, player: *Cat, obstacles: []ScrollEntity, cloud: []ScrollEntity, ground: sf.RectangleShape) void {
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
    window.*.display();
}
