// Composites snapshot PNGs into the README hero image.
// Usage: swift scripts/compose-hero.swift <out.png> <popoverLeft> <popoverRight> <widgetTopRight> <widgetBottomRight>
import AppKit

let a = CommandLine.arguments
guard a.count == 6 else { print("usage: compose-hero out left right topRight bottomRight"); exit(1) }

func load(_ p: String) -> CGImage {
    let img = NSImage(contentsOfFile: p)!
    var r = NSRect(origin: .zero, size: img.size)
    return img.cgImage(forProposedRect: &r, context: nil, hints: nil)!
}

let left = load(a[2]), right = load(a[3]), topRight = load(a[4]), bottomRight = load(a[5])
let margin: CGFloat = 120, gap: CGFloat = 90
let colW = CGFloat(max(topRight.width, bottomRight.width))
let width = margin * 2 + CGFloat(left.width) + gap + CGFloat(right.width) + gap + colW
let height: CGFloat = 1480

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Background: night-to-dusk gradient with stars.
let bg = CGGradient(colorsSpace: cs, colors: [color(0x070B24), color(0x1A1F55), color(0x4A2F78), color(0x9C4F7A)] as CFArray,
                    locations: [0, 0.45, 0.8, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
var seed: UInt64 = 99
func rnd() -> CGFloat { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return CGFloat(seed % 10_000) / 10_000 }
for _ in 0..<220 {
    let r = 1.2 + rnd() * 3
    ctx.setFillColor(color(0xFFFFFF, 0.15 + rnd() * 0.55))
    ctx.fillEllipse(in: CGRect(x: rnd() * width, y: rnd() * height, width: r, height: r))
}

func draw(_ img: CGImage, x: CGFloat, y: CGFloat, radius: CGFloat?) {
    let rect = CGRect(x: x, y: y, width: CGFloat(img.width), height: CGFloat(img.height))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: color(0x000000, 0.55))
    if let radius {
        // Rounded card with shadow: fill the shape, then draw the clipped image on top.
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.addPath(path); ctx.setFillColor(color(0x1E1E1E)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.draw(img, in: rect)
        ctx.restoreGState()
        ctx.addPath(path); ctx.setStrokeColor(color(0xFFFFFF, 0.14)); ctx.setLineWidth(2); ctx.strokePath()
    } else {
        ctx.draw(img, in: rect) // already has rounded corners and transparency
        ctx.restoreGState()
    }
}

let lx = margin
draw(left, x: lx, y: (height - CGFloat(left.height)) / 2 + 30, radius: 26)
let rx = lx + CGFloat(left.width) + gap
draw(right, x: rx, y: (height - CGFloat(right.height)) / 2 - 30, radius: 26)
let cx = rx + CGFloat(right.width) + gap
let stack = CGFloat(topRight.height + bottomRight.height) + 10
let top = (height + stack) / 2
draw(topRight, x: cx + (colW - CGFloat(topRight.width)) / 2, y: top - CGFloat(topRight.height), radius: nil)
draw(bottomRight, x: cx + (colW - CGFloat(bottomRight.width)) / 2, y: top - stack, radius: nil)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[1]))
print("wrote \(a[1]) \(Int(width))x\(Int(height))")
