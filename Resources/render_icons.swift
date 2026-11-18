import AppKit

// 用法: swiftc render_icons.swift -o render_icons && ./render_icons <输出目录>
// 以 Core Graphics 矢量方式渲染，各尺寸独立绘制，避免降采样导致的模糊。

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "."

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])!
}

func makeContext(_ px: Int) -> CGContext {
    CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func savePNG(_ image: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        NSLog("PNG 写入失败: \(path)"); return
    }
    try? data.write(to: URL(fileURLWithPath: path))
}

// MARK: - App 图标（文档 + 放大镜，带层次/阴影/玻璃质感）
func renderAppIcon(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    let s = CGFloat(px)
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1) // 转为左上原点，便于按视觉坐标布局

    // 1. 圆角背景 + 清新淡蓝渐变 + 顶部柔光
    let bgRect = CGRect(x: 0.045 * s, y: 0.045 * s, width: 0.91 * s, height: 0.91 * s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 0.22 * s, cornerHeight: 0.22 * s, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgGrad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgba(0.49, 0.75, 0.99), rgba(0.24, 0.56, 0.94), rgba(0.13, 0.40, 0.82)] as CFArray,
        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0.2 * s, y: 0), end: CGPoint(x: 0.8 * s, y: s), options: [])
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgba(1, 1, 1, 0.30), rgba(1, 1, 1, 0)] as CFArray,
        locations: [0, 1])!
    ctx.drawRadialGradient(glow,
        startCenter: CGPoint(x: 0.30 * s, y: 0.10 * s), startRadius: 0,
        endCenter: CGPoint(x: 0.30 * s, y: 0.10 * s), endRadius: 0.85 * s, options: [])
    ctx.restoreGState()

    // 后续所有内容裁剪在圆角背景内，避免手柄/阴影溢出 squircle
    ctx.addPath(bgPath)
    ctx.clip()

    func setShadow(_ dy: CGFloat, _ blur: CGFloat, _ alpha: CGFloat) {
        ctx.setShadow(offset: CGSize(width: 0, height: dy * s), blur: blur * s,
                      color: rgba(0.04, 0.07, 0.25, alpha))
    }

    // 2. 后层文档（右上露出，制造叠放层次）
    ctx.saveGState()
    setShadow(0.03, 0.05, 0.22)
    let backRect = CGRect(x: 0.315 * s, y: 0.18 * s, width: 0.42 * s, height: 0.56 * s)
    let backPath = CGPath(roundedRect: backRect, cornerWidth: 0.035 * s, cornerHeight: 0.035 * s, transform: nil)
    ctx.setFillColor(rgba(0.94, 0.96, 1.0, 0.95))
    ctx.addPath(backPath)
    ctx.fillPath()
    ctx.restoreGState()

    // 3. 前层主文档（白到浅蓝渐变）
    let frontRect = CGRect(x: 0.235 * s, y: 0.22 * s, width: 0.43 * s, height: 0.57 * s)
    let frontPath = CGPath(roundedRect: frontRect, cornerWidth: 0.035 * s, cornerHeight: 0.035 * s, transform: nil)
    ctx.saveGState()
    setShadow(0.035, 0.06, 0.30)
    ctx.addPath(frontPath)
    ctx.clip()
    let docGrad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgba(1, 1, 1), rgba(0.90, 0.93, 0.99)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(docGrad,
        start: CGPoint(x: 0.45 * s, y: 0.22 * s), end: CGPoint(x: 0.45 * s, y: 0.79 * s), options: [])
    ctx.restoreGState()

    // 4. 文档文字线条
    let lineColor = rgba(0.66, 0.74, 0.90, 0.95)
    for i in 0..<3 {
        let y = (0.35 + CGFloat(i) * 0.085) * s
        let w = (i == 2 ? 0.18 : 0.27) * s
        let r = CGRect(x: 0.285 * s, y: y, width: w, height: 0.026 * s)
        ctx.setFillColor(lineColor)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 0.013 * s, cornerHeight: 0.013 * s, transform: nil))
        ctx.fillPath()
    }

    // 5. 放大镜
    let cx = 0.615 * s, cy = 0.645 * s, r = 0.145 * s
    // 镜片
    ctx.saveGState()
    setShadow(0.02, 0.04, 0.30)
    ctx.setFillColor(rgba(1, 1, 1, 0.55))
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r - 0.018 * s,
               startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.fillPath()
    ctx.restoreGState()
    // 镜圈（渐变描边：clip 出环形后填充渐变）
    let ringGrad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgba(0.45, 0.72, 1.0), rgba(0.14, 0.42, 0.84)] as CFArray,
        locations: [0, 1])!
    ctx.saveGState()
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
               startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r - 0.036 * s,
               startAngle: 2 * CGFloat.pi, endAngle: 0, clockwise: true)
    ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(ringGrad,
        start: CGPoint(x: cx - r, y: cy - r), end: CGPoint(x: cx + r, y: cy + r), options: [])
    ctx.restoreGState()
    // 镜片高光弧
    ctx.saveGState()
    ctx.setStrokeColor(rgba(1, 1, 1, 0.65))
    ctx.setLineWidth(0.012 * s)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r - 0.055 * s,
               startAngle: CGFloat.pi * 0.78, endAngle: CGFloat.pi * 1.32, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()
    // 手柄
    ctx.saveGState()
    setShadow(0.015, 0.03, 0.25)
    let k: CGFloat = 0.707
    let handleStart = CGPoint(x: cx + (r - 0.01 * s) * k, y: cy + (r - 0.01 * s) * k)
    let handleEnd = CGPoint(x: cx + 0.26 * s, y: cy + 0.26 * s)
    ctx.setStrokeColor(rgba(0.20, 0.36, 0.86))
    ctx.setLineWidth(0.072 * s)
    ctx.setLineCap(.round)
    ctx.move(to: handleStart)
    ctx.addLine(to: handleEnd)
    ctx.strokePath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - 菜单栏图标（单色模板，深浅色自动反转）
func renderMenuIcon(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    let s = CGFloat(px)
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setStrokeColor(rgba(0, 0, 0, 1))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let cx = 0.405 * s, cy = 0.395 * s, r = 0.24 * s
    ctx.setLineWidth(0.105 * s)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
               startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.strokePath()

    ctx.setLineWidth(0.14 * s)
    ctx.move(to: CGPoint(x: 0.575 * s, y: 0.565 * s))
    ctx.addLine(to: CGPoint(x: 0.855 * s, y: 0.855 * s))
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - 输出
let iconsetDir = outDir + "/icon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let appSizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in appSizes {
    savePNG(renderAppIcon(px), iconsetDir + "/" + name)
}

// 菜单栏：22pt @1x 与 @2x(Retina) 两套
savePNG(renderMenuIcon(22), outDir + "/MenuIcon.png")
savePNG(renderMenuIcon(44), outDir + "/MenuIcon@2x.png")

print("矢量图标渲染完成 -> \(outDir)")
