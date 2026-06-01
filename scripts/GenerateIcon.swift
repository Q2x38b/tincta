#!/usr/bin/env swift
//
// Renders Tincta's app icon (martini-glass-with-pick line drawing from the
// user-supplied SVG) at 1024×1024. Outputs three variants:
//
//   - AppIcon-light.png   — dark stroke on transparent background
//   - AppIcon-dark.png    — light stroke on transparent background
//   - logo-transparent.png — same as light, for the Logo imageset / splash
//
// Re-run any time with:
//   swift scripts/GenerateIcon.swift
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvasSize: CGFloat = 1024
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptDir.deletingLastPathComponent()
let iconSetDir = repoRoot.appendingPathComponent("Tincta/Assets.xcassets/AppIcon.appiconset")
let logoSetDir = repoRoot.appendingPathComponent("Tincta/Assets.xcassets/Logo.imageset")
let launchLogoDir = repoRoot.appendingPathComponent("Tincta/Assets.xcassets/LaunchLogo.imageset")

// MARK: - Stroke palette

let darkStroke = CGColor(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1.0)
let lightStroke = CGColor(red: 0xF4/255, green: 0xEF/255, blue: 0xE6/255, alpha: 1.0)

// MARK: - SVG path → CGPath

/// Builds the four paths from the user's SVG as a single CGMutablePath so
/// the stroke renders as one continuous shape — overlapping strokes won't
/// show alpha blending at intersections.
func buildIconPath() -> CGMutablePath {
    let p = CGMutablePath()

    // Path 1 — Cocktail glass bowl (V-cone with rounded top corners).
    p.move(to: CGPoint(x: 8.20538, y: 15.3582))
    p.addLine(to: CGPoint(x: 4.51713, y: 11.0812))
    p.addCurve(to: CGPoint(x: 2.09833, y: 6.89474),
               control1: CGPoint(x: 2.62475, y: 8.88671),
               control2: CGPoint(x: 1.67856, y: 7.78948))
    p.addCurve(to: CGPoint(x: 6.90099, y: 6),
               control1: CGPoint(x: 2.5181,  y: 6),
               control2: CGPoint(x: 3.97907, y: 6))
    p.addLine(to: CGPoint(x: 11.099, y: 6))
    p.addCurve(to: CGPoint(x: 15.9017, y: 6.89474),
               control1: CGPoint(x: 14.0209, y: 6),
               control2: CGPoint(x: 15.4819, y: 6))
    p.addCurve(to: CGPoint(x: 13.4829, y: 11.0812),
               control1: CGPoint(x: 16.3214, y: 7.78948),
               control2: CGPoint(x: 15.3753, y: 8.88671))
    p.addLine(to: CGPoint(x: 9.79462, y: 15.3582))
    p.addCurve(to: CGPoint(x: 9, y: 16),
               control1: CGPoint(x: 9.42563, y: 15.7861),
               control2: CGPoint(x: 9.24114, y: 16))
    p.addCurve(to: CGPoint(x: 8.20538, y: 15.3582),
               control1: CGPoint(x: 8.75886, y: 16),
               control2: CGPoint(x: 8.57437, y: 15.7861))
    p.closeSubpath()

    // Path 2 — Garnish stick / stirrer.
    p.move(to: CGPoint(x: 8.5, y: 6))
    p.addLine(to: CGPoint(x: 8.09898, y: 3.59389))
    p.addCurve(to: CGPoint(x: 7.42882, y: 2.80961),
               control1: CGPoint(x: 8.03809, y: 3.22852),
               control2: CGPoint(x: 7.78022, y: 2.92674))
    p.addLine(to: CGPoint(x: 5, y: 2))

    // Path 3 — Stem + base.
    p.move(to: CGPoint(x: 9, y: 16))
    p.addLine(to: CGPoint(x: 9, y: 22))
    p.move(to: CGPoint(x: 7.5, y: 22))
    p.addLine(to: CGPoint(x: 10.5, y: 22))

    // Path 4 — Olive / garnish circle to the upper right.
    p.move(to: CGPoint(x: 15.8601, y: 8.83333))
    p.addCurve(to: CGPoint(x: 18.4822, y: 10),
               control1: CGPoint(x: 16.5043, y: 9.54937),
               control2: CGPoint(x: 17.4403, y: 10))
    p.addCurve(to: CGPoint(x: 22, y: 6.5),
               control1: CGPoint(x: 20.425, y: 10),
               control2: CGPoint(x: 22, y: 8.433))
    p.addCurve(to: CGPoint(x: 18.4822, y: 3),
               control1: CGPoint(x: 22, y: 4.567),
               control2: CGPoint(x: 20.425, y: 3))
    p.addCurve(to: CGPoint(x: 15, y: 6),
               control1: CGPoint(x: 16.71, y: 3),
               control2: CGPoint(x: 15.2438, y: 4.30385))

    return p
}

// MARK: - Drawing

/// Centres the 24×24 SVG into the 1024×1024 canvas with a 6% margin,
/// then strokes with the requested colour.
func drawIcon(in ctx: CGContext, strokeColor: CGColor) {
    let canvas = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)

    ctx.saveGState()

    // CGBitmapContext uses Quartz Y-up coordinates (origin at bottom-left).
    // The SVG is Y-down (origin at top-left). Flip the context vertically
    // BEFORE applying the SVG scale + translate so the icon renders the
    // right way up.
    ctx.translateBy(x: 0, y: canvas.height)
    ctx.scaleBy(x: 1, y: -1)

    // Centre the 24×24 SVG into the canvas. Margin is much larger than
    // before (was 0.10) so the icon sits as a small, comfortable mark in
    // the centre rather than filling the whole tile — both for the app
    // icon and for the splash logo.
    let svgSize: CGFloat = 24
    let margin: CGFloat = canvasSize * 0.26
    let drawableSide = canvasSize - margin * 2
    let scale = drawableSide / svgSize
    ctx.translateBy(x: (canvas.width - drawableSide) / 2,
                    y: (canvas.height - drawableSide) / 2)
    ctx.scaleBy(x: scale, y: scale)

    let path = buildIconPath()
    ctx.addPath(path)
    ctx.setStrokeColor(strokeColor)
    // Solid stroke; width is in SVG units (scales with the context).
    ctx.setLineWidth(2.0)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    ctx.restoreGState()
}

// MARK: - PNG output

func renderPNG(strokeColor: CGColor, to url: URL) throws {
    let bitmapInfo: UInt32 =
        CGBitmapInfo.byteOrder32Big.rawValue |
        CGImageAlphaInfo.premultipliedLast.rawValue

    guard let ctx = CGContext(
        data: nil,
        width: Int(canvasSize),
        height: Int(canvasSize),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to make CGContext")
    }

    drawIcon(in: ctx, strokeColor: strokeColor)

    guard let cgImage = ctx.makeImage() else {
        fatalError("Failed to make CGImage")
    }

    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { fatalError("Failed to create PNG destination at \(url.path)") }

    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Failed to finalise PNG at \(url.path)")
    }
    print("✓ wrote \(url.path)")
}

// MARK: - Run

do {
    // App icon — dark variant (light strokes on transparent for dark
    // Home Screen).
    try renderPNG(strokeColor: lightStroke,
                  to: iconSetDir.appendingPathComponent("AppIcon-dark.png"))

    // App icon — light variant (dark strokes on transparent for the
    // default / light Home Screen).
    try renderPNG(strokeColor: darkStroke,
                  to: iconSetDir.appendingPathComponent("AppIcon-light.png"))

    // Logo asset — used by the splash screen + anywhere else we show
    // the wordless mark. Light strokes so it reads on the dark splash bg.
    try renderPNG(strokeColor: lightStroke,
                  to: logoSetDir.appendingPathComponent("logo-transparent.png"))

    // Launch logo @3x — small version iOS shows centred during the
    // pre-app system launch screen.
    try renderPNG(strokeColor: lightStroke,
                  to: launchLogoDir.appendingPathComponent("launch-logo.png"))

    print("Done.")
} catch {
    print("Failed: \(error)")
    exit(1)
}
