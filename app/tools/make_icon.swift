// Puts a transparent PNG on the app icon's midnight background: 1024×1024, sRGB, no alpha (App Store rule).
//   xcrun swiftc -O tools/make_icon.swift -o /tmp/make_icon && /tmp/make_icon flatten <in.png> <out.png>
// import_art.sh uses it to build a fallback icon from the praying scroll when art/icon_1024.png is missing.
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
    print("usage: make_icon flatten <in.png> <out.png>")
    exit(1)
}

switch args[1] {
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
