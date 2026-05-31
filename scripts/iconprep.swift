import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// 用法: swift iconprep.swift <src.png> <dst.png> [cutoff]
// 从四边泛洪去除“浅色外框”（白底 + 银色边框），直到遇到深色图标本体；
// 再裁剪到本体、居中放入透明正方形画布，输出全幅透明 PNG（无外框、无白边）。
guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: iconprep <src> <dst> [cutoff]\n".utf8)); exit(2)
}
let srcPath = CommandLine.arguments[1]
let dstPath = CommandLine.arguments[2]
let cutoff: UInt8 = CommandLine.arguments.count >= 4 ? (UInt8(CommandLine.arguments[3]) ?? 120) : 120

guard let imgSrc = CGImageSourceCreateWithURL(URL(fileURLWithPath: srcPath) as CFURL, nil),
      let cg = CGImageSourceCreateImageAtIndex(imgSrc, 0, nil) else {
    FileHandle.standardError.write(Data("cannot load source\n".utf8)); exit(1)
}

let w = cg.width, h = cg.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: w * 4, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

// 浅色判定：最小通道 >= cutoff 视为“外框/背景”。
@inline(__always) func isLight(_ i: Int) -> Bool {
    return px[i] >= cutoff && px[i + 1] >= cutoff && px[i + 2] >= cutoff
}

// 从四边泛洪，把连通的浅色像素设为透明（仅去除与边缘相连的浅色，保留内部高光）。
var stack = [Int]()
stack.reserveCapacity(w * h / 4)
func seed(_ x: Int, _ y: Int) {
    let p = y * w + x
    if px[p * 4 + 3] != 0 && isLight(p * 4) { stack.append(p) }
}
for x in 0..<w { seed(x, 0); seed(x, h - 1) }
for y in 0..<h { seed(0, y); seed(w - 1, y) }

while let p = stack.popLast() {
    let i = p * 4
    if px[i + 3] == 0 { continue }
    if !isLight(i) { continue }
    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0
    let x = p % w, y = p / w
    if x > 0 { stack.append(p - 1) }
    if x < w - 1 { stack.append(p + 1) }
    if y > 0 { stack.append(p - w) }
    if y < h - 1 { stack.append(p + w) }
}

// 内容包围盒
var minX = w, minY = h, maxX = -1, maxY = -1
for y in 0..<h {
    for x in 0..<w where px[(y * w + x) * 4 + 3] != 0 {
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
    }
}
guard maxX >= minX, maxY >= minY else {
    FileHandle.standardError.write(Data("no content found\n".utf8)); exit(1)
}

guard let masked = ctx.makeImage() else { exit(1) }
let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
guard let cropped = masked.cropping(to: cropRect) else { exit(1) }

// 居中放入透明正方形画布（边长=内容较长边）
let side = max(cropRect.width, cropRect.height)
guard let outCtx = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8,
                             bytesPerRow: 0, space: cs,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
outCtx.clear(CGRect(x: 0, y: 0, width: side, height: side))
let dx = (side - cropRect.width) / 2
let dy = (side - cropRect.height) / 2
outCtx.draw(cropped, in: CGRect(x: dx, y: dy, width: cropRect.width, height: cropRect.height))
guard let squared = outCtx.makeImage() else { exit(1) }

guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: dstPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, squared, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("wrote \(dstPath) cropped \(Int(cropRect.width))x\(Int(cropRect.height)) from \(w)x\(h) cutoff=\(cutoff)")
