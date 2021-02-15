//
//  Decolorize.swift
//  diig
//
//  Created by Radovan Paška on 15.02.2021.
//
//  implementation if decolorize: http://www.eyemaginary.com/Portfolio/TurnColorsGray.html
//

import Foundation
import UIKit
import SwiftUI
import Accelerate
import simd

final class Decolorize {
    
    @Binding var decolorizeProcess: Float

    private let imageData: CFMutableData
    private let imageDataPointer: UnsafeMutablePointer<UInt8>
    private let imageSize: CGSize
    private let imagePixels: Int
    private let effect: Float
    private let noise: Float
    
    private let tol: Float = 100 * Float.ulpOfOne
    
    private let luminanceMax: Float = 1.0
    private let luminanceScale: Float = 0.66856793424088827189
    private let saturationMax: Float = 1.1180339887498948482
    
    private var weights: simd_float3x3 {
        let rows = [
            simd_float3(0.2989360212937753847527155, 0.5870430744511212909351327, 0.1140209042551033243121518),
            simd_float3(0.5, 0.5, -1.0),
            simd_float3(1.0, -1.0, 0.0)
        ]
        
        return float3x3(rows: rows)
    }
    
    public init(
        with data: CFMutableData,
        size: CGSize,
        effect: Float = 0.5,
        noise: Float = 0.001,
        progress: Binding<Float>
    ) {
        self.imageData = data
        self.imageSize = size
        self.effect = effect
        self.noise = noise
        self._decolorizeProcess = progress

        self.imagePixels = Int(imageSize.width * imageSize.height)
        self.imageDataPointer = CFDataGetMutableBytePtr(imageData)
    }
    
    public func getMonochromeImage() -> CFMutableData {
        let alter = effect * (luminanceMax / saturationMax)
        
        // dims = np.shape(RGB) = width, height, bytes-per-pixel (3 for non-alpha, 4 for alpha)
        // TODO
        
        return imageData
    }
    
    private func getYPQCh() -> [simd_float3] {
        let rgb = getRGB()
        var ypqc = [simd_float3]()
        
        for i in 0..<rgb.count {
            ypqc[i] = rgb[i] * weights // channels ypq
            ypqc[i][3] = sqrt(pow(ypqc[i][1], 2) + pow(ypqc[i][2], 2)) // channel Ch; sqrt(P^2 + Q^2)
        }

        return ypqc
    }
    
    private func getRGB() -> [simd_float3] {
        var rgb = [simd_float3]()
        
        let maxValue: Float = 255.0
        for i in stride(from: 0, to: imagePixels, by: 4) { // Each pixel is ARGB.
            let r = Float(imageDataPointer[i] + 0) / maxValue
            let g = Float(imageDataPointer[i] + 1) / maxValue
            let b = Float(imageDataPointer[i] + 2) / maxValue
            
            rgb[i] = simd_float3(r, g, b)
        }
        
        return rgb
    }
    
    // Legacy conversion to bnw and planar8.
    static func planar8(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            fatalError("Unable to get CGImage.")
        }
        
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
