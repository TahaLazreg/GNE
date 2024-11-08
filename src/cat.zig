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

const Cat = @This();

hitBox: sf.RectangleShape,
currPosition: sf.Vector2(f32),
initPosition: sf.Vector2(f32),

// Sprite and animation - render
sprite: sf.Sprite,
spriteFrame: u8 = 0,
spriteAnimationTimeAcc: f32 = 0,

// Jump handling - phys
isJumping: bool = false,
halfJumptime: f32 = 1.0 / 60.0 * 45.0,
jumpHeight: f32 = 90,
currJumpTime: f32 = 0,

const catWidth = 30;
const catHeight = 20;

var texture: ?sf.Texture = null;

pub fn create(w_width: comptime_int, w_height: comptime_int, allocator: std.mem.Allocator) !*Cat {
    if (Cat.texture == null) {
        texture = try sf.Texture.createFromFile("./Assets/Mousse.png");
    }
    const pos = .{ .x = w_width / 6, .y = 2 * w_height / 3 };
    const text = texture.?;

    var sprite = try sf.Sprite.createFromTexture(text);
    sprite.setTextureRect(.{ .top = 0, .left = 0, .width = catWidth, .height = catHeight });
    sprite.setPosition(pos);

    var hitBox = try sf.RectangleShape.create(.{ .x = catWidth - 3, .y = catHeight - 3 });
    hitBox.setPosition(pos);
    hitBox.setTexture(Cat.texture.?);

    const newPlayer: *Cat = try allocator.create(Cat);
    newPlayer.* = Cat{ .hitBox = hitBox, .sprite = sprite, .currPosition = pos, .initPosition = pos };
    return newPlayer;
}

pub fn destroy(self: *Cat) void {
    self.hitBox.destroy();
    self.sprite.destroy();
}

pub fn render_update(self: *Cat, dt: f32) bool {
    if (!self.animateSprite(dt)) {
        return false;
    }
    self.sprite.setPosition(self.currPosition);
    self.hitBox.setPosition(self.currPosition);
    return true;
}

pub fn phys_update(self: *Cat, dt: f32) bool {
    if (self.isJumping) {
        self.handleJump(dt);
    }
    return true;
}

pub fn jump(self: *Cat) void {
    self.isJumping = true;
}

pub fn handleJump(self: *Cat, dt: f32) void {
    self.currJumpTime += dt;
    if (self.currJumpTime < self.halfJumptime) {
        self.currPosition.y -= (self.jumpHeight / self.halfJumptime) * dt;
    } else {
        self.currPosition.y += (self.jumpHeight / self.halfJumptime) * dt;
    }

    if (self.currJumpTime >= 2 * self.halfJumptime) {
        self.currPosition = self.initPosition;
        self.isJumping = false;
        self.currJumpTime = 0;
    }
    self.sprite.setPosition(self.currPosition);
}

pub fn animateSprite(self: *Cat, dt: f32) bool {
    // Don't animate jump, just go new sprite TODO
    if (self.isJumping) return true;

    // Animate run at 12fps
    self.spriteAnimationTimeAcc += dt;
    if (self.spriteAnimationTimeAcc >= 1.0 / 12.0) { // TODO change to an animation entity
        var sprite = sf.Sprite.createFromTexture(texture.?) catch {
            print("ERROR: Could not find texture for sprite update, exiting...", .{});
            return false;
        };
        sprite.setTextureRect(.{ .top = 0, .left = self.spriteFrame * catWidth, .width = catWidth, .height = catHeight });
        self.sprite.destroy();
        self.sprite = sprite;

        self.spriteFrame += 1;
        self.spriteFrame %= 4;
        self.spriteAnimationTimeAcc -= 1.0 / 12.0;
    }
    return true;
}
