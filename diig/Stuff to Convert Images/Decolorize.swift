//
//  Decolorize.swift
//  diig
//
//  Created by Radovan Paška on 15.02.2021.
//

import Foundation
import UIKit
import Accelerate

final class Decolorize {
    
    static func planar8(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            fatalError("Unable to get CGImage.")
        }
        
        // Apple says this is how people see. Let's believe them.
        let redCoefficient: Float = 0.2126
        let greenCoefficient: Float = 0.7152
        let blueCoefficient: Float = 0.0722
        
        let divisor: Int32 = 0x1000
        let fDivisor = Float(divisor)
        
        var coefficientsMatrix = [
            Int16(redCoefficient * fDivisor),
            Int16(greenCoefficient * fDivisor),
            Int16(blueCoefficient * fDivisor)
        ]
        
        let preBias: [Int16] = [0, 0, 0, 0]
        let postBias: Int32 = 0
        
        var sourceBuffer = VImageBuffers.getSourceBuffer(for: cgImage)
        var destinationBuffer = VImageBuffers.getDestinationBuffer(
            for: cgImage,
            with: sourceBuffer
        )
        
        defer {
            sourceBuffer.free()
            destinationBuffer.free()
        }
        
        vImageMatrixMultiply_ARGB8888ToPlanar8(
            &sourceBuffer,
            &destinationBuffer,
            &coefficientsMatrix,
            divisor,
            preBias,
            postBias,
            vImage_Flags(kvImageNoFlags)
        )
        
        guard let monoFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            colorSpace: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent
        ) else {
            fatalError("Unable to create monochrome image.")
        }
        
        guard let result = try? destinationBuffer.createCGImage(format: monoFormat) else {
            fatalError("Unable to create image")
        }
        
        return UIImage(cgImage: result)
    }
}
