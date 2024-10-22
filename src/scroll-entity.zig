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

const Entity = @This();

hitBox: sf.RectangleShape,
currPosition: sf.Vector2(f32),
initPosition: sf.Vector2(f32),

// Sprite and animation - render
sprite: sf.Sprite,
spriteFrame: u8 = 0,
spriteAnimationTimeAcc: f32 = 0,

// Collision mgmt
collidesPlayer: bool = false,

// Phys
speed: f32,
direction: sf.Vector2(f32),

// Random
rng: std.Random,

var texture: ?sf.Texture = null;

pub fn create(w_width: comptime_int, w_height: comptime_int, textPath: [:0]const u8, spd: f32, colPlayer: bool) !Entity {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    if (Entity.texture == null) {
        texture = try sf.Texture.createFromFile(textPath);
    }
    const pos = .{ .x = w_width + 35, .y = w_height / 3 + (@mod(rand.float(f32), 90) - 50.0) };
    const text = texture.?;

    var sprite = try sf.Sprite.createFromTexture(text);
    sprite.setTextureRect(.{ .top = 0, .left = 0, .width = 30, .height = 20 });
    sprite.setPosition(pos);

    var hitBox = try sf.RectangleShape.create(.{ .x = 30, .y = 20 });
    hitBox.setPosition(pos);
    hitBox.setTexture(Entity.texture.?);

    const dir = .{ .x = -1, .y = 0 };

    const newPlayer = Entity{ .hitBox = hitBox, .sprite = sprite, .currPosition = pos, .initPosition = pos, .rng = rand, .direction = dir, .collidesPlayer = colPlayer, .speed = spd };
    return newPlayer;
}

pub fn destroy(self: *Entity) void {
    self.hitBox.destroy();
    self.sprite.destroy();
}

pub fn render_update(self: *Entity, dt: f32) bool {
    _ = dt;
    self.sprite.setPosition(self.currPosition);
    self.hitBox.setPosition(self.currPosition);
    return true;
}

pub fn phys_update(self: *Entity, dt: f32) bool {
    self.scroll(dt);
    return true;
}

pub fn jump(self: *Entity) void {
    self.isJumping = true;
}

pub fn scroll(self: *Entity, dt: f32) void {
    const newPos = self.currPosition.substract(self.direction.scale(dt * self.speed));
    self.currPosition = newPos;
}

pub fn animateSprite(self: *Entity, dt: f32) bool {
    // Don't animate jump, just go new sprite TODO
    if (self.isJumping) return true;

    // Animate run at 12fps
    self.spriteAnimationTimeAcc += dt;
    if (self.spriteAnimationTimeAcc >= 1.0 / 12.0) { // TODO change to an animation entity
        var sprite = sf.Sprite.createFromTexture(texture.?) catch {
            print("ERROR: Could not find texture for sprite update, exiting...", .{});
            return false;
        };
        sprite.setTextureRect(.{ .top = 0, .left = self.spriteFrame * 30, .width = 30, .height = 20 });
        self.sprite.destroy();
        self.sprite = sprite;

        self.spriteFrame += 1;
        self.spriteFrame %= 4;
        self.spriteAnimationTimeAcc -= 1.0 / 12.0;
    }
    return true;
}
