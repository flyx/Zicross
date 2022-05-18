const std = @import("std");
const SDL = @import("sdl2");
const resources = @import("resources.zig");

var data: [20][40]bool = undefined;

fn loadData() !void {
  const file =
    try std.fs.openFileAbsolute(resources.data, .{.read = true, .write = false});
  defer file.close();
  for (data) |*row| {
    var buffer: [41]u8 = undefined;
    const len = try file.readAll(&buffer);
    for (row) |*cell, x| {
      cell.* = if (x < len) buffer[x] == 'x' else false;
    }
  }
}

pub fn main() !void {
  try loadData();

  try SDL.init(.{
      .video = true,
      .events = true,
      .audio = true,
  });
  defer SDL.quit();
  
  var window = try SDL.createWindow(
      "Zicross Demo",
      .{ .centered = {} }, .{ .centered = {} },
      640, 480,
      .{ .shown = true },
  );
  defer window.destroy();
  
  var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
  defer renderer.destroy();
  
  mainLoop: while (true) {
    while (SDL.pollEvent()) |ev| {
      switch (ev) {
        .quit => break :mainLoop,
        else => {},
      }
    }
    
    try renderer.setColorRGB(0, 0, 0);
    try renderer.clear();
    
    const size = try renderer.getOutputSize();
    const rect = SDL.Rectangle{
      .x      = @divTrunc(size.width_pixels - 401, 2),
      .y      = @divTrunc(size.height_pixels - 201, 2),
      .width  = 401,
      .height = 201,
    };
    try renderer.setColorRGB(255, 255, 255);
    try renderer.fillRect(rect);
    
    try renderer.setColorRGB(128, 128, 128);
    var i: i32 = 0; while (i <= data.len) : (i += 1) {
      try renderer.setScale(1.0, 1.0);
      try renderer.drawLine(rect.x, rect.y + i * 10, rect.x + rect.width, rect.y + i * 10);
    }
    i = 0; while (i <= data[0].len) : (i += 1) {
      try renderer.setScale(1.0, 1.0);
      try renderer.drawLine(rect.x + i * 10, rect.y, rect.x + i * 10, rect.y + rect.height);
    }
    
    try renderer.setColorRGB(0, 0, 0);
    for (data) |row, y| {
      for (row) |cell, x| {
        if (cell) {
          try renderer.fillRect(.{
            .x      = rect.x + @intCast(c_int, x * 10),
            .y      = rect.y + @intCast(c_int, y * 10),
            .width  = 10,
            .height = 10,
          });
        }
      }
    }

    renderer.present();
  }
}