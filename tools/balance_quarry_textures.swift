// swift tools/balance_quarry_textures.swift <directory with original photo downloads>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let side = 64
let assets = "assets/quarry-textures/"
let photos = CommandLine.arguments[1]
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue
typealias RGB = SIMD3<Double>

func sample(_ path: String) -> [Double] {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let photo = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let canvas = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                           bytesPerRow: side * 4, space: colorSpace, bitmapInfo: bitmap)!
    canvas.interpolationQuality = .high
    canvas.draw(photo, in: CGRect(x: 0, y: 0, width: side, height: side))
    let p = canvas.data!.assumingMemoryBound(to: UInt8.self)
    return (0..<(side * side)).map { i in
        Double(p[4*i])*0.2126 + Double(p[4*i+1])*0.7152 + Double(p[4*i+2])*0.0722
    }
}

// Blur over the wrap boundary as well, so the seam isn't sharpened by the grade.
func blurred(_ values: [Double], passes: Int) -> [Double] {
    var result = values
    for _ in 0..<passes {
        let previous = result
        for y in 0..<side {
            for x in 0..<side {
                var sum = 0.0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let weight = Double((2-abs(dy)) * (2-abs(dx)))
                        sum += previous[((y+dy+side)%side)*side + (x+dx+side)%side] * weight
                    }
                }
                result[y*side+x] = sum/16
            }
        }
    }
    return result
}

func grade(_ source: String, _ name: String, _ palette: [RGB], _ transform: ([Double]) -> [Double]) {
    let field = transform(sample(source))
    let ranks = field.sorted()
    let low = ranks[ranks.count*3/100], mid = ranks[ranks.count/2], high = ranks[ranks.count*97/100]
    let canvas = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                           bytesPerRow: side * 4, space: colorSpace, bitmapInfo: bitmap)!
    let p = canvas.data!.assumingMemoryBound(to: UInt8.self)
    for (i, value) in field.enumerated() {
        let band = value < mid ? 0 : 1
        let from = band == 0 ? low : mid, to = band == 0 ? mid : high
        let t = min(1, max(0, (value-from)/max(to-from, 0.01)))
        let rgb = palette[band]*(1-t) + palette[band+1]*t
        for c in 0..<3 { p[i*4+c] = UInt8(rgb[c].rounded()) }
        p[i*4+3] = 255
    }
    let url = URL(fileURLWithPath: assets + name + ".png")
    let png = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(png, canvas.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(png))
}

// Separate contrast budgets: soft turf, readable stones, quiet cliffs,
// clear paving joints, and mineral veins with no ink-black gaps.
grade(photos + "/grass_ground.jpg", "grass-short",
      [RGB(108,125,67), RGB(131,148,82), RGB(155,166,103)]) { values in
    let clumps = blurred(values, passes: 1)
    let broad = blurred(values, passes: 12)
    return zip(zip(values, clumps), broad).map { pair, base in
        (pair.0-base)*0.24 + (pair.1-base)*0.57 + base*0.19
    }
}
grade(photos + "/ganges_river_pebbles.jpg", "field-aggregate",
      [RGB(86,84,91), RGB(127,124,130), RGB(160,157,157)]) { $0 }
grade(assets + "cliff.png", "cliff-soft-strata",
      [RGB(121,96,83), RGB(154,125,103), RGB(189,155,121)]) { blurred($0, passes: 2) }
grade(assets + "rock.png", "stone-soft",
      [RGB(106,110,117), RGB(140,143,146), RGB(167,171,171)]) { blurred($0, passes: 1) }
grade(assets + "paving.png", "paving-worn-joints",
      [RGB(107,115,123), RGB(144,149,152), RGB(176,178,175)]) { $0 }
grade(assets + "ore-vein.png", "ore-satin-vein",
      [RGB(99,106,121), RGB(154,159,168), RGB(220,223,222)]) { blurred($0, passes: 1) }
grade(assets + "ruby-leaves.png", "ruby-loam",
      [RGB(116,73,65), RGB(159,103,82), RGB(191,137,108)]) { blurred($0, passes: 1) }
