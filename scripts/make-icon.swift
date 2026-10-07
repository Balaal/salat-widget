// Renders the app icon (1024x1024 PNG) with CoreGraphics.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// macOS icon grid: 824pt body centred, continuous-corner radius ~185.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(shape)
ctx.setFillColor(color(0x0B1030))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape)
ctx.clip()

// Sky gradient: deep night at top to warm dusk at the horizon.
let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                     colors: [color(0x070B24), color(0x1A1F55), color(0x4A2F78), color(0xC4627A), color(0xF2A35E)] as CFArray,
                     locations: [0, 0.38, 0.66, 0.86, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

// Stars
var seed: UInt64 = 42
func rnd() -> CGFloat {
    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return CGFloat(seed % 10_000) / 10_000
}
for _ in 0..<60 {
    let x = body.minX + rnd() * body.width
    let y = body.minY + body.height * 0.45 + rnd() * body.height * 0.55
    let r = 1.5 + rnd() * 3.5
    ctx.setFillColor(color(0xFFFFFF, 0.35 + rnd() * 0.6))
    ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
}

// Crescent moon with glow
let moonCenter = CGPoint(x: 600, y: 650)
let moonR: CGFloat = 175
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 70, color: color(0xF7D27A, 0.85))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setFillColor(color(0xF7D27A))
ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR * 2, height: moonR * 2))
ctx.setBlendMode(.clear)
ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonR + 78, y: moonCenter.y - moonR + 52, width: moonR * 2, height: moonR * 2))
ctx.endTransparencyLayer()
ctx.restoreGState()

// Star beside the crescent
func star(center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<(points * 2) {
        let r = i % 2 == 0 ? outer : inner
        let a = CGFloat(i) * .pi / CGFloat(points) + .pi / 2
        let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 30, color: color(0xF7D27A, 0.9))
ctx.addPath(star(center: CGPoint(x: 700, y: 640), outer: 44, inner: 18, points: 5))
ctx.setFillColor(color(0xFBE3A0))
ctx.fillPath()
ctx.restoreGState()

// Mosque silhouette on the horizon
let sil = CGMutablePath()
let baseY: CGFloat = 100
// ground
sil.addRect(CGRect(x: 100, y: baseY, width: 824, height: 70))
// main hall
sil.addRect(CGRect(x: 330, y: baseY + 60, width: 364, height: 130))
// main dome
sil.move(to: CGPoint(x: 360, y: baseY + 188))
sil.addCurve(to: CGPoint(x: 512, y: baseY + 380), control1: CGPoint(x: 350, y: baseY + 300), control2: CGPoint(x: 450, y: baseY + 350))
sil.addCurve(to: CGPoint(x: 664, y: baseY + 188), control1: CGPoint(x: 574, y: baseY + 350), control2: CGPoint(x: 674, y: baseY + 300))
sil.closeSubpath()
// finial
sil.addRect(CGRect(x: 507, y: baseY + 375, width: 10, height: 50))
sil.addEllipse(in: CGRect(x: 499, y: baseY + 420, width: 26, height: 26))
// side domes
for cx in [270.0, 754.0] as [CGFloat] {
    sil.addRect(CGRect(x: cx - 60, y: baseY + 60, width: 120, height: 80))
    sil.move(to: CGPoint(x: cx - 55, y: baseY + 138))
    sil.addQuadCurve(to: CGPoint(x: cx + 55, y: baseY + 138), control: CGPoint(x: cx, y: baseY + 240))
    sil.closeSubpath()
}
// minarets
for mx in [170.0, 854.0] as [CGFloat] {
    sil.addRect(CGRect(x: mx - 22, y: baseY + 60, width: 44, height: 360))
    sil.addRect(CGRect(x: mx - 32, y: baseY + 330, width: 64, height: 18))
    sil.move(to: CGPoint(x: mx - 22, y: baseY + 418))
    sil.addLine(to: CGPoint(x: mx, y: baseY + 490))
    sil.addLine(to: CGPoint(x: mx + 22, y: baseY + 418))
    sil.closeSubpath()
}
ctx.addPath(sil)
ctx.setFillColor(color(0x0A0D26, 0.96))
ctx.fillPath()

// Glossy top highlight
let gloss = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [color(0xFFFFFF, 0.14), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.midY), options: [])
ctx.restoreGState()

// Hairline border
ctx.addPath(shape)
ctx.setStrokeColor(color(0xFFFFFF, 0.12))
ctx.setLineWidth(3)
ctx.strokePath()

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
