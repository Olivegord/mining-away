import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let items: [(String, [[Double]])] = [
    ("cliff", [[91,55,60],[168,105,81],[237,174,123]]),
    ("grass", [[43,74,55],[108,147,66],[177,201,101]]),
    ("gravel", [[82,70,78],[155,133,112],[224,195,149]]),
    ("paving", [[79,91,112],[151,160,168],[217,223,209]]),
    ("canopy", [[60,88,64],[111,145,92],[163,185,120]]),
    ("evergreen", [[51,77,70],[93,128,108],[140,163,128]]),
    ("ruby-leaves", [[74,24,28],[173,49,35],[240,104,53]])
]
let root = "assets/quarry-textures/"
for (name, palette) in items {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: root + name + ".png") as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let pixels = ctx.data!.assumingMemoryBound(to: UInt8.self)
    let luma = (0..<(w*h)).map { i in Double(pixels[i*4])*0.2126 + Double(pixels[i*4+1])*0.7152 + Double(pixels[i*4+2])*0.0722 }
    let sorted = luma.sorted(), n = sorted.count
    let lo = sorted[n*3/100], mid = sorted[n/2], hi = sorted[n*97/100]
    for (i, v) in luma.enumerated() {
        let index = v < mid ? 0 : 1
        let from = index == 0 ? lo : mid, to = index == 0 ? mid : hi
        let t = min(1, max(0, (v-from)/max(to-from,1)))
        for c in 0..<3 {
            let band = palette[index][c] * (1-t) + palette[index+1][c] * t
            pixels[4*i+c] = UInt8(band.rounded())
        }
    }
    let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: root + name + "-graded.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dst))
    print("\(name): \(w)x\(h) diffuse, original luminance \(Int(lo))/\(Int(mid))/\(Int(hi))")
}
