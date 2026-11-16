// Pray to Scroll app icon, drawn in code.
//   xcrun swiftc -O tools/make_icon.swift -o /tmp/make_icon && /tmp/make_icon icon <out.png> [size]
//   /tmp/make_icon flatten <in.png> <out.png>   (puts any PNG on the midnight background: RGB, no alpha)
//
// The icon: a midnight gradient, a warm glow, and a gold key whose bow is an arched doorway with a small
// cross of light inside it. 1024×1024, sRGB, no alpha (App Store requirement).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(_ size: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Work in a 1024-point, top-left-origin space.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: CGFloat(size) / 1024, y: -CGFloat(size) / 1024)
    ctx.interpolationQuality = .high
    return ctx
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

func drawBackground(_ ctx: CGContext) {
    ctx.drawLinearGradient(gradient([rgb(0x1A2A47), rgb(0x0E1726), rgb(0x070C16)], [0, 0.55, 1]),
                           start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])
    ctx.drawRadialGradient(gradient([rgb(0xE9B949, 0.42), rgb(0xE9B949, 0.12), rgb(0xE9B949, 0)], [0, 0.45, 1]),
                           startCenter: CGPoint(x: 512, y: 400), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 400), endRadius: 520, options: [])
}

/// Arch-topped rectangle (a doorway) in top-left coordinates.
func archPath(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGPath {
    let r = width / 2
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: y + height))
    path.addLine(to: CGPoint(x: x, y: y + r))
    path.addArc(center: CGPoint(x: x + r, y: y + r), radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
    path.addLine(to: CGPoint(x: x + width, y: y + height))
    path.closeSubpath()
    return path
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawKey(_ ctx: CGContext) {
    let gold = gradient([rgb(0xFBE7AE), rgb(0xF5D58A), rgb(0xE9B949), rgb(0xB8862B)], [0, 0.25, 0.6, 1])

    // The key's silhouette: bow (doorway ring) + collar + shaft + bit.
    let key = CGMutablePath()
    let outer = archPath(x: 322, y: 132, width: 380, height: 470)
    key.addPath(outer)
    key.addPath(roundedRect(CGRect(x: 432, y: 584, width: 160, height: 44), 14))        // collar
    key.addPath(roundedRect(CGRect(x: 480, y: 610, width: 64, height: 300), 20))        // shaft
    key.addPath(roundedRect(CGRect(x: 520, y: 752, width: 120, height: 46), 12))        // upper tooth
    key.addPath(roundedRect(CGRect(x: 520, y: 838, width: 96, height: 46), 12))         // lower tooth

    // Soft shadow + warm glow under the key.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: rgb(0x000000, 0.55))
    ctx.addPath(key)
    ctx.setFillColor(rgb(0xB8862B))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 70, color: rgb(0xE9B949, 0.55))
    ctx.addPath(key)
    ctx.clip()
    ctx.drawLinearGradient(gold, start: CGPoint(x: 330, y: 130), end: CGPoint(x: 700, y: 910), options: [])
    ctx.restoreGState()

    // Bevel highlight along the top of the arch.
    ctx.saveGState()
    ctx.addPath(outer)
    ctx.setStrokeColor(rgb(0xFFF6DA, 0.55))
    ctx.setLineWidth(6)
    ctx.clip()
    ctx.addPath(archPath(x: 325, y: 135, width: 374, height: 600))
    ctx.strokePath()
    ctx.restoreGState()

    // The doorway opening: deep ink with light spilling out from the cross.
    let door = archPath(x: 384, y: 194, width: 256, height: 352)
    ctx.saveGState()
    ctx.addPath(door)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0x22345A), rgb(0x111C30)], [0, 1]),
                           start: CGPoint(x: 512, y: 194), end: CGPoint(x: 512, y: 546), options: [])
    ctx.drawRadialGradient(gradient([rgb(0xF5D58A, 0.75), rgb(0xE9B949, 0.25), rgb(0xE9B949, 0)], [0, 0.4, 1]),
                           startCenter: CGPoint(x: 512, y: 372), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 372), endRadius: 190, options: [])
    // floor light
    ctx.drawRadialGradient(gradient([rgb(0xFBE7AE, 0.55), rgb(0xFBE7AE, 0)], [0, 1]),
                           startCenter: CGPoint(x: 512, y: 546), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 546), endRadius: 150, options: [])
    ctx.restoreGState()

    // Inner rim of the doorway.
    ctx.saveGState()
    ctx.addPath(door)
    ctx.setStrokeColor(rgb(0x8A6420, 0.9))
    ctx.setLineWidth(5)
    ctx.strokePath()
    ctx.restoreGState()

    // The small cross of light.
    let cross = CGMutablePath()
    cross.addPath(roundedRect(CGRect(x: 498, y: 282, width: 28, height: 190), 10))
    cross.addPath(roundedRect(CGRect(x: 452, y: 330, width: 120, height: 28), 10))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40, color: rgb(0xFFF3C4, 1))
    ctx.addPath(cross)
    ctx.setFillColor(rgb(0xFFFAEB))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 14, color: rgb(0xFFFFFF, 0.9))
    ctx.addPath(cross)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
}

func write(_ ctx: CGContext, to path: String) {
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("could not write \(path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: make_icon icon <out.png> [size] | flatten <in.png> <out.png>")
    exit(1)
}

switch args[1] {
case "icon":
    let size = args.count > 3 ? Int(args[3]) ?? 1024 : 1024
    let ctx = makeContext(size)
    drawBackground(ctx)
    drawKey(ctx)
    write(ctx, to: args[2])
case "flatten":
    guard args.count >= 4,
          let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("could not read \(args[2])")
    }
    let ctx = makeContext(1024)
    drawBackground(ctx)
    ctx.saveGState()
    // undo the flip for image drawing
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    ctx.restoreGState()
    write(ctx, to: args[3])
default:
    print("unknown command \(args[1])")
    exit(1)
}
