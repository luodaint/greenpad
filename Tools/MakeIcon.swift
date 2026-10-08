import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let entries: [(String, Int)] = [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32), ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64), ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256), ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512), ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]
for (name, size) in entries {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 74, y: 74, width: 876, height: 876), xRadius: 194, yRadius: 194)
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.46, blue: 0.32, alpha: 1), ending: NSColor(srgbRed: 0.07, green: 0.27, blue: 0.18, alpha: 1))!.draw(in: background, angle: 90)
    NSColor(srgbRed: 0.95, green: 0.97, blue: 0.90, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 254, y: 226, width: 516, height: 592), xRadius: 54, yRadius: 54).fill()
    NSColor(srgbRed: 0.78, green: 0.84, blue: 0.70, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 284, y: 226, width: 30, height: 592), xRadius: 12, yRadius: 12).fill()
    NSColor(srgbRed: 0.30, green: 0.49, blue: 0.36, alpha: 1).setFill()
    for (y, width) in [(658.0, 288.0), (558.0, 288.0), (458.0, 208.0)] {
        NSBezierPath(roundedRect: NSRect(x: 370, y: y, width: width, height: 22), xRadius: 11, yRadius: 11).fill()
    }
    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 606, y: 246))
    leaf.curve(to: NSPoint(x: 792, y: 426), controlPoint1: NSPoint(x: 554, y: 370), controlPoint2: NSPoint(x: 654, y: 424))
    leaf.curve(to: NSPoint(x: 606, y: 246), controlPoint1: NSPoint(x: 798, y: 300), controlPoint2: NSPoint(x: 698, y: 218))
    NSColor(srgbRed: 0.47, green: 0.71, blue: 0.36, alpha: 1).setFill(); leaf.fill()
    let stem = NSBezierPath(); stem.move(to: NSPoint(x: 574, y: 216)); stem.line(to: NSPoint(x: 746, y: 378)); stem.lineWidth = 12; stem.lineCapStyle = .round
    NSColor(srgbRed: 0.20, green: 0.43, blue: 0.25, alpha: 1).setStroke(); stem.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
}
