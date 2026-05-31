#!/usr/bin/env swift
//
// Renders Tincta's logo at 1024×1024 using CoreGraphics and writes two PNGs:
//   - logo-transparent.png   (alpha background — for marketing/share assets)
//   - AppIcon-1024.png       (solid parchment background — for AppIcon.appiconset)
//
// Run from the repo root:
//   swift scripts/GenerateIcon.swift
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit  // for NSColor convenience only

let size: CGFloat = 1024
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptDir.deletingLastPathComponent()
let iconSetDir = repoRoot.appendingPathComponent("Tincta/Assets.xcassets/AppIcon.appiconset")
let assetsDir = repoRoot.appendingPathComponent("Tincta/Assets.xcassets")

// MARK: - Palette

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red:   CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue:  CGFloat(b) / 255,
            alpha: a)
}

let parchment     = rgb(0xF4, 0xEF, 0xE6)
let glassStroke   = rgb(0x2A, 0x21, 0x16, 0.92)   // warm near-black
let glassHighlight = rgb(0xFF, 0xFF, 0xFF, 0.55)
let liquidTop     = rgb(0xE5, 0xA3, 0x55)         // amber, lit
let liquidBottom  = rgb(0x9B, 0x57, 0x1F)         // amber, deep
let liquidShadow  = rgb(0x6A, 0x3B, 0x12, 0.45)
let iceFill       = rgb(0xFF, 0xFF, 0xFF, 0.45)
let iceHighlight  = rgb(0xFF, 0xFF, 0xFF, 0.80)
let iceShadow     = rgb(0x55, 0x2A, 0x0E, 0.35)

// MARK: - Drawing

/// Build the outline path of a rocks glass within `rect`. The glass is a
/// slight outward taper (tumbler) with a rounded base and a sharp rim, sized
/// for a generous interior so the liquid + ice read cleanly.
func glassPath(in rect: CGRect) -> CGMutablePath {
    let inset: CGFloat = rect.width * 0.04
    let r = rect.insetBy(dx: inset, dy: inset)
    let topInset: CGFloat = r.width * 0.04
    let baseInset: CGFloat = r.width * 0.10
    let baseRadius: CGFloat = r.width * 0.10
    let rimRadius: CGFloat = r.width * 0.03

    // Coordinates: y increases downward; we work with the rect top/bottom and
    // then flip the whole context once at draw time.
    let topLeft  = CGPoint(x: r.minX + topInset,  y: r.minY)
    let topRight = CGPoint(x: r.maxX - topInset,  y: r.minY)
    let botLeft  = CGPoint(x: r.minX + baseInset, y: r.maxY)
    let botRight = CGPoint(x: r.maxX - baseInset, y: r.maxY)

    let p = CGMutablePath()
    p.move(to: CGPoint(x: topLeft.x + rimRadius, y: topLeft.y))
    p.addLine(to: CGPoint(x: topRight.x - rimRadius, y: topRight.y))
    p.addQuadCurve(to: CGPoint(x: topRight.x, y: topRight.y + rimRadius),
                   control: topRight)
    // Right wall, gentle outward then inward toward the base
    p.addCurve(to: botRight,
               control1: CGPoint(x: topRight.x + r.width * 0.012, y: r.midY),
               control2: CGPoint(x: botRight.x + r.width * 0.008, y: r.maxY - baseRadius * 0.6))
    // Base curve
    p.addQuadCurve(to: CGPoint(x: botLeft.x, y: botLeft.y),
                   control: CGPoint(x: r.midX, y: r.maxY + baseRadius * 0.35))
    // Left wall mirror
    p.addCurve(to: CGPoint(x: topLeft.x, y: topLeft.y + rimRadius),
               control1: CGPoint(x: botLeft.x - r.width * 0.008, y: r.maxY - baseRadius * 0.6),
               control2: CGPoint(x: topLeft.x - r.width * 0.012, y: r.midY))
    p.addQuadCurve(to: CGPoint(x: topLeft.x + rimRadius, y: topLeft.y),
                   control: topLeft)
    p.closeSubpath()
    return p
}

/// Rounded-square ice cube path centred near the glass middle.
func iceCubePath(in glassRect: CGRect) -> CGMutablePath {
    let side = glassRect.width * 0.42
    let cx = glassRect.midX - glassRect.width * 0.02
    let cy = glassRect.midY + glassRect.height * 0.08
    let rect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
    return CGPath(roundedRect: rect, cornerWidth: side * 0.12, cornerHeight: side * 0.12, transform: nil) as! CGMutablePath
}

/// Specular highlight: a curving sliver near the upper-left of the glass.
func highlightPath(in glassRect: CGRect) -> CGMutablePath {
    let p = CGMutablePath()
    let x = glassRect.minX + glassRect.width * 0.16
    let topY = glassRect.minY + glassRect.height * 0.20
    let bottomY = glassRect.maxY - glassRect.height * 0.22
    p.move(to: CGPoint(x: x, y: topY))
    p.addQuadCurve(to: CGPoint(x: x + glassRect.width * 0.025, y: bottomY),
                   control: CGPoint(x: x - glassRect.width * 0.02, y: glassRect.midY))
    return p
}

func drawIcon(in ctx: CGContext, canvas: CGRect, withBackground: Bool) {
    ctx.saveGState()

    if withBackground {
        ctx.setFillColor(parchment)
        // Slightly inset rounded square reads as "icon shape" even with the
        // system's mask, but full-bleed gives the system room to clip.
        ctx.fill(canvas)
    }

    // Flip Y so our math reads top-down, which matches design tools.
    ctx.translateBy(x: 0, y: canvas.height)
    ctx.scaleBy(x: 1, y: -1)

    let glassRect = CGRect(
        x: canvas.width * 0.16,
        y: canvas.height * 0.13,
        width: canvas.width * 0.68,
        height: canvas.height * 0.74
    )
    let glass = glassPath(in: glassRect)

    // Soft drop shadow behind the glass
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18),
                  blur: 36,
                  color: rgb(0, 0, 0, 0.18))
    ctx.addPath(glass)
    ctx.setFillColor(rgb(0xFF, 0xFF, 0xFF, 0.02))
    ctx.fillPath()
    ctx.restoreGState()

    // ─── Liquid (clipped to glass), with vertical gradient
    ctx.saveGState()
    ctx.addPath(glass)
    ctx.clip()

    let liquidTopY = glassRect.minY + glassRect.height * 0.34
    let liquidRect = CGRect(x: glassRect.minX - 20,
                            y: liquidTopY,
                            width: glassRect.width + 40,
                            height: glassRect.maxY - liquidTopY + 20)

    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [liquidTop, liquidBottom] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: liquidRect.midX, y: liquidRect.minY),
        end:   CGPoint(x: liquidRect.midX, y: liquidRect.maxY),
        options: []
    )

    // A meniscus line where liquid meets air
    ctx.setStrokeColor(rgb(0x7A, 0x46, 0x18, 0.55))
    ctx.setLineWidth(canvas.width * 0.006)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: glassRect.minX + glassRect.width * 0.08, y: liquidTopY))
    ctx.addLine(to: CGPoint(x: glassRect.maxX - glassRect.width * 0.08, y: liquidTopY))
    ctx.strokePath()

    // ─── Ice (also under clip so the cube sits inside the glass)
    let ice = iceCubePath(in: glassRect)
    ctx.setShadow(offset: CGSize(width: 0, height: 8),
                  blur: 12,
                  color: iceShadow)
    ctx.addPath(ice)
    ctx.setFillColor(iceFill)
    ctx.fillPath()

    // Ice highlights
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let iceBox = ice.boundingBoxOfPath
    let highlight = CGMutablePath()
    let hx = iceBox.minX + iceBox.width * 0.12
    let hy = iceBox.minY + iceBox.height * 0.12
    let hw = iceBox.width * 0.28
    let hh = iceBox.height * 0.10
    highlight.addRoundedRect(in: CGRect(x: hx, y: hy, width: hw, height: hh),
                             cornerWidth: hh / 2, cornerHeight: hh / 2)
    ctx.addPath(highlight)
    ctx.setFillColor(iceHighlight)
    ctx.fillPath()

    ctx.restoreGState()

    // ─── Glass outline
    ctx.addPath(glass)
    ctx.setStrokeColor(glassStroke)
    ctx.setLineWidth(canvas.width * 0.022)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.strokePath()

    // ─── Inner specular highlight
    ctx.addPath(highlightPath(in: glassRect))
    ctx.setStrokeColor(glassHighlight)
    ctx.setLineWidth(canvas.width * 0.012)
    ctx.setLineCap(.round)
    ctx.strokePath()

    // ─── Small base reflection ellipse
    let baseEllipse = CGRect(x: glassRect.midX - glassRect.width * 0.22,
                             y: glassRect.maxY + canvas.height * 0.02,
                             width: glassRect.width * 0.44,
                             height: canvas.height * 0.018)
    if withBackground {
        ctx.setFillColor(rgb(0, 0, 0, 0.10))
        ctx.fillEllipse(in: baseEllipse)
    }

    ctx.restoreGState()
}

// MARK: - PNG writing

func renderPNG(transparent: Bool, to url: URL) throws {
    let bitmapInfo: UInt32 = transparent
        ? (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        : (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue)

    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to make CGContext")
    }

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    drawIcon(in: ctx, canvas: canvas, withBackground: !transparent)

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
    try renderPNG(transparent: true,
                  to: assetsDir.appendingPathComponent("Logo.imageset/logo-transparent.png"))
    try renderPNG(transparent: false,
                  to: iconSetDir.appendingPathComponent("AppIcon-1024.png"))
    print("Done.")
} catch {
    print("Failed: \(error)")
    exit(1)
}
