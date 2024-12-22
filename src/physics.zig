const std = @import("std");
const print = std.debug.print;
const Cat = @import("./cat.zig");
const ScrollEntity = @import("./scroll-entity.zig");

const sf = struct {
    const sfml = @import("sfml");
    pub usingnamespace sfml;
    pub usingnamespace sfml.window;
    pub usingnamespace sfml.graphics;
    pub usingnamespace sfml.audio;
    pub usingnamespace sfml.system;
};

const CollisionObject = struct {
    hitBox: sf.RectangleShape,
    uuid: u32,
};

const phys_update: comptime_float = 1.0 / 60.0;
const broadphaseDivision = 3;
const nbObstacles = 1;

pub fn physicsUpdate(accumulator: *f32, player: *Cat, obstacles: []ScrollEntity, cloud: []ScrollEntity, timer: *f32, nbClouds: comptime_int, w_width: comptime_int, w_height: comptime_int) void {
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
    var allObjects: [nbObstacles + 1]CollisionObject = undefined;

    for (allObjects, 0..) |_, y| {
        if (y == obstacles.len) {
            const obstcl_strct: CollisionObject = .{ .hitBox = player.hitBox, .uuid = player.uuid };
            allObjects[y] = obstcl_strct;
        } else {
            const obstcl_strct: CollisionObject = .{ .hitBox = obstacles[y].hitBox, .uuid = obstacles[y].uuid };
            allObjects[y] = obstcl_strct;
        }
    }

    //// Check positions of objects in the grid & create lists of objects per grid+
    i = 0;
    var objectsInQuadrants: [broadphaseDivision * broadphaseDivision][allObjects.len]?CollisionObject = undefined;

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
            broadphase(&allObjects, i, j, &objectsInQuadrants[i * 3 + j], w_width, w_height);
        }
    }

    //// Check collision of objects pairwise if they are in the same list
    i = 0;
    while (i < broadphaseDivision * broadphaseDivision) : (i += 1) {
        for (objectsInQuadrants[i]) |first| {
            if (first) |colliderOne|
                for (objectsInQuadrants[i]) |second| {
                    if (second) |colliderTwo| {
                        if (colliderOne.uuid != colliderTwo.uuid and narrowphase(colliderOne.hitBox, colliderTwo.hitBox)) {
                            print("Collision detected {d}, {d}\n", .{ colliderOne.uuid, colliderTwo.uuid });
                            if (colliderOne.uuid == player.uuid or colliderTwo.uuid == player.uuid) {
                                print("Player hit\n", .{});
                                reset(obstacles, timer);
                            }
                        }
                    } else continue;
                } else continue;
        }
    }
}

pub fn broadphase(allObjects: []CollisionObject, i: u8, j: u8, quad: *[nbObstacles + 1]?CollisionObject, w_width: comptime_int, w_height: comptime_int) void {
    // Check all objects
    var nbObjInArr: u8 = 0;
    for (allObjects) |obj| {
        var k: u8 = 0;
        const hitBox = obj.hitBox;
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
                quad[nbObjInArr] = obj;
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

    if (&first == &second) return false;

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

pub fn reset(allObjects: []ScrollEntity, timer: *f32) void {
    for (allObjects) |*obj| {
        _ = obj.*.reset();
        timer.* = 0;
    }
}
