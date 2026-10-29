import Flutter
import UIKit

/// Native renderers of the overlay bitmaps (the Android twin is OverlayRenderers.kt). The preview and the
/// export draw the very same PNGs, so what is seen is what is exported. Sizes follow the frame width:
/// 1 "unit" = frameW / 360 pixels.
enum OverlayRenderer {
    static func color(_ v: Any?, alpha: CGFloat? = nil) -> UIColor {
        let n = (v as? NSNumber)?.int64Value ?? 0xFF00_0000
        let a = CGFloat((n >> 24) & 0xFF) / 255
        let r = CGFloat((n >> 16) & 0xFF) / 255
        let g = CGFloat((n >> 8) & 0xFF) / 255
        let b = CGFloat(n & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: alpha ?? a)
    }

    private static func num(_ d: [String: Any], _ k: String, _ def: Double = 0) -> Double {
        (d[k] as? NSNumber)?.doubleValue ?? def
    }

    private static func png(_ size: CGSize, _ draw: (CGContext) -> Void) -> FlutterStandardTypedData {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { draw($0.cgContext) }
        return FlutterStandardTypedData(bytes: img.pngData() ?? Data())
    }

    private static func font(_ name: String, _ size: CGFloat, bold: Bool) -> UIFont {
        let family: String
        switch name {
        case "serif": family = "Georgia"
        case "mono": family = "Courier"
        case "cursive": family = "Snell Roundhand"
        case "condensed": family = "AvenirNextCondensed-" + (bold ? "Bold" : "Regular")
        default: family = ""
        }
        if !family.isEmpty, let f = UIFont(name: family, size: size) { return f }
        return UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    // MARK: text

    static func text(_ clip: [String: Any], frameW: Int) -> [String: Any] {
        let u = CGFloat(frameW) / 360
        let size = CGFloat(num(clip, "sizeU", 20)) * u
        let bold = clip["bold"] as? Bool ?? false
        let outline = clip["outline"] as? Bool ?? false
        let shadow = clip["shadow"] as? Bool ?? false
        let hasBox = clip["box"] != nil
        let f = font(clip["font"] as? String ?? "barlow", size, bold: bold)
        let lines = ((clip["text"] as? String) ?? "").components(separatedBy: "\n")
        let lineH = size * 1.2
        let haloPad: CGFloat = outline ? max(2, size * 0.16) : 0
        let shadowR: CGFloat = shadow ? size * 0.12 : 0
        let boxPad: CGFloat = hasBox ? size * 0.35 : 0
        let pad = haloPad + boxPad + shadowR * 2 + 4 * u
        let widths = lines.map { ($0 as NSString).size(withAttributes: [.font: f]).width }
        let textW = widths.max() ?? 0
        let w = max(8, ceil(textW + pad * 2))
        let h = max(8, ceil(lineH * CGFloat(lines.count) + pad * 2))
        let fill = color(clip["color"], alpha: 1)
        let align = clip["align"] as? String ?? "center"
        let data = png(CGSize(width: w, height: h)) { c in
            if hasBox {
                let inset = pad - boxPad - shadowR
                let r = CGRect(x: inset, y: inset, width: w - inset * 2, height: h - inset * 2)
                c.setFillColor(color(clip["box"]).cgColor)
                c.addPath(UIBezierPath(roundedRect: r, cornerRadius: size * 0.3).cgPath)
                c.fillPath()
            }
            for (i, line) in lines.enumerated() {
                let lw = widths[i]
                let x: CGFloat
                switch align {
                case "left": x = pad
                case "right": x = w - pad - lw
                default: x = (w - lw) / 2
                }
                let y = pad + lineH * CGFloat(i)
                if outline {
                    (line as NSString).draw(
                        at: CGPoint(x: x, y: y),
                        withAttributes: [
                            .font: f, .strokeColor: haloColor(fill), .strokeWidth: 8,
                            .foregroundColor: haloColor(fill),
                        ])
                }
                if shadow {
                    c.setShadow(
                        offset: CGSize(width: shadowR * 0.5, height: shadowR * 0.7), blur: shadowR,
                        color: UIColor(white: 0, alpha: 0.67).cgColor)
                }
                (line as NSString).draw(
                    at: CGPoint(x: x, y: y), withAttributes: [.font: f, .foregroundColor: fill])
                c.setShadow(offset: .zero, blur: 0, color: nil)
            }
        }
        return ["png": data, "w": Int(w), "h": Int(h)]
    }

    private static func haloColor(_ c: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        return lum > 0.5 ? UIColor(white: 0, alpha: 0.85) : UIColor(white: 1, alpha: 0.85)
    }

    // MARK: cover (the solid block; blur, mosaic and spotlight are not drawn on iOS yet)

    static func cover(_ clip: [String: Any], frameW: Int, frameH: Int) -> [String: Any] {
        let u = CGFloat(frameW) / 360
        let w = max(8, CGFloat((num(clip, "x1") - num(clip, "x0")) * Double(frameW)))
        let h = max(8, CGFloat((num(clip, "y1") - num(clip, "y0")) * Double(frameH)))
        let col = color(clip["color"], alpha: 1)
        let data = png(CGSize(width: w, height: h)) { c in
            c.setFillColor(col.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: 6 * u).cgPath)
            c.fillPath()
        }
        return ["png": data, "w": Int(w), "h": Int(h)]
    }

    // MARK: shape / bubble

    static func shape(_ clip: [String: Any], frameW: Int, frameH: Int) -> [String: Any] {
        let u = CGFloat(frameW) / 360
        let stroke = max(1, CGFloat(num(clip, "strokeU", 4)) * u)
        let bw = CGFloat(num(clip, "w", 0.3)) * CGFloat(frameW)
        let bh = CGFloat(num(clip, "h", 0.2)) * CGFloat(frameH)
        let kind = clip["kind"] as? String ?? "rect"
        let tailDx = CGFloat(num(clip, "tailX", -0.15)) * CGFloat(frameW)
        let tailDy = CGFloat(num(clip, "tailY", 0.18)) * CGFloat(frameH)
        let halfW = (kind == "bubble" ? max(bw / 2, abs(tailDx)) : bw / 2) + stroke * 2 + 2
        let halfH = (kind == "bubble" ? max(bh / 2, abs(tailDy)) : bh / 2) + stroke * 2 + 2
        let w = max(8, ceil(halfW * 2))
        let h = max(8, ceil(halfH * 2))
        let col = color(clip["color"], alpha: 1)
        let filled = clip["filled"] as? Bool ?? false
        let data = png(CGSize(width: w, height: h)) { c in
            let rect = CGRect(x: w / 2 - bw / 2, y: h / 2 - bh / 2, width: bw, height: bh)
            c.setStrokeColor(col.cgColor)
            c.setFillColor(col.cgColor)
            c.setLineWidth(stroke)
            c.setLineCap(.round)
            c.setLineJoin(.round)
            switch kind {
            case "ellipse":
                filled ? c.fillEllipse(in: rect) : c.strokeEllipse(in: rect)
            case "line":
                c.move(to: CGPoint(x: rect.minX, y: rect.minY))
                c.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                c.strokePath()
            case "arrow":
                let p0 = CGPoint(x: rect.minX, y: rect.minY)
                let p1 = CGPoint(x: rect.maxX, y: rect.maxY)
                c.move(to: p0)
                c.addLine(to: p1)
                c.strokePath()
                let ang = atan2(p1.y - p0.y, p1.x - p0.x)
                let head = stroke * 4.5
                for side in [-1.0, 1.0] {
                    let a = ang + .pi + CGFloat(side) * 0.5
                    c.move(to: p1)
                    c.addLine(to: CGPoint(x: p1.x + cos(a) * head, y: p1.y + sin(a) * head))
                    c.strokePath()
                }
            case "bubble":
                let body = UIBezierPath(roundedRect: rect, cornerRadius: min(bw, bh) * 0.2)
                let tail = UIBezierPath()
                let base = CGPoint(x: rect.midX, y: rect.midY)
                let tip = CGPoint(x: base.x + tailDx, y: base.y + tailDy)
                let nx = -(tip.y - base.y)
                let ny = tip.x - base.x
                let len = max(1, (nx * nx + ny * ny).squareRoot())
                let k = min(bw, bh) * 0.12 / len
                tail.move(to: CGPoint(x: base.x + nx * k, y: base.y + ny * k))
                tail.addLine(to: tip)
                tail.addLine(to: CGPoint(x: base.x - nx * k, y: base.y - ny * k))
                tail.close()
                body.append(tail)
                c.addPath(body.cgPath)
                filled ? c.fillPath() : c.strokePath()
                if let t = clip["text"] as? String, !t.isEmpty {
                    let f = UIFont.systemFont(ofSize: min(bh * 0.4, 18 * u), weight: .semibold)
                    let sz = (t as NSString).size(withAttributes: [.font: f])
                    (t as NSString).draw(
                        at: CGPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2),
                        withAttributes: [.font: f, .foregroundColor: color(clip["textColor"], alpha: 1)])
                }
            default:
                filled
                    ? c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: stroke).cgPath)
                    : c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: stroke).cgPath)
                filled ? c.fillPath() : c.strokePath()
            }
        }
        return ["png": data, "w": Int(w), "h": Int(h)]
    }

    // MARK: marker body (a simple look on iOS; the animated cue ring is drawn by the preview)

    static func marker(_ spec: [String: Any], frameW: Int, frameH: Int) -> [String: Any] {
        let u = CGFloat(frameW) / 360
        let type = spec["type"] as? String ?? "finger"
        let scale = CGFloat(num(spec, "scale", 1))
        let thick = max(2, CGFloat(num(spec, "thickness", 5)) * u * 0.5)
        let col = color(spec["color"])
        var half = 45 * u * max(1, scale)
        let x0 = CGFloat(num(spec, "x0", 0.5)), y0 = CGFloat(num(spec, "y0", 0.5))
        let x1 = CGFloat(num(spec, "x1", 0.5)), y1 = CGFloat(num(spec, "y1", 0.5))
        var boxW: CGFloat = 0, boxH: CGFloat = 0
        if type == "circle" || type == "rect" {
            boxW = abs(x1 - x0) * CGFloat(frameW)
            boxH = abs(y1 - y0) * CGFloat(frameH)
            half = max(boxW, boxH) / 2 + thick * 2
        }
        let side = max(8, ceil(half * 2))
        let rot = CGFloat(num(spec, "rotation", 0)) * .pi / 180
        let data = png(CGSize(width: side, height: side)) { c in
            c.translateBy(x: side / 2, y: side / 2)
            c.rotate(by: rot)
            c.setStrokeColor(col.cgColor)
            c.setFillColor(col.withAlphaComponent(0.35).cgColor)
            c.setLineWidth(thick)
            c.setLineCap(.round)
            c.setLineJoin(.round)
            let r = half - thick
            switch type {
            case "circle":
                c.strokeEllipse(in: CGRect(x: -boxW / 2, y: -boxH / 2, width: boxW, height: boxH))
            case "rect":
                c.stroke(CGRect(x: -boxW / 2, y: -boxH / 2, width: boxW, height: boxH))
            case "arrow":
                c.move(to: CGPoint(x: -r, y: 0))
                c.addLine(to: CGPoint(x: r, y: 0))
                c.move(to: CGPoint(x: r - r * 0.4, y: -r * 0.4))
                c.addLine(to: CGPoint(x: r, y: 0))
                c.addLine(to: CGPoint(x: r - r * 0.4, y: r * 0.4))
                c.strokePath()
            case "pen":
                let pts = (spec["points"] as? [NSNumber])?.map { CGFloat($0.doubleValue) } ?? []
                if pts.count >= 4 {
                    var cx: CGFloat = 0, cy: CGFloat = 0
                    for i in stride(from: 0, to: pts.count - 1, by: 2) { cx += pts[i]; cy += pts[i + 1] }
                    let n = CGFloat(pts.count / 2)
                    cx /= n; cy /= n
                    c.move(to: CGPoint(x: (pts[0] - cx) * CGFloat(frameW), y: (pts[1] - cy) * CGFloat(frameH)))
                    for i in stride(from: 2, to: pts.count - 1, by: 2) {
                        c.addLine(to: CGPoint(x: (pts[i] - cx) * CGFloat(frameW), y: (pts[i + 1] - cy) * CGFloat(frameH)))
                    }
                    c.strokePath()
                }
            default:  // finger, ripple, number: a soft disc with a ring
                c.fillEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
                c.strokeEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
                if type == "number" {
                    let t = "\(Int(num(spec, "number", 1)))" as NSString
                    let f = UIFont.systemFont(ofSize: r, weight: .bold)
                    let sz = t.size(withAttributes: [.font: f])
                    t.draw(
                        at: CGPoint(x: -sz.width / 2, y: -sz.height / 2),
                        withAttributes: [.font: f, .foregroundColor: col])
                }
            }
        }
        return ["png": data, "half": Double(side / 2)]
    }
}
