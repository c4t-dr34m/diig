//
//  ImageTransformations.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit
import SwiftUI
import Accelerate

final class Transformations {
    
    static func scalePlanar8(image: UIImage, to targetSize: Int) -> UIImage {
        guard let cgImage = image.cgImage, cgImage.bitsPerPixel == 8 else {
            fatalError("Unable to get CGImage. Maybe it's not Planar8.")
        }
        
        let ratioHorizontal  = CGFloat(targetSize) / image.size.width
        let ratioVertical = CGFloat(targetSize) / image.size.height
        
        let width: CGFloat
        let height: CGFloat
        if ratioHorizontal < ratioVertical {
            width = image.size.width * ratioHorizontal
            height = image.size.height * ratioHorizontal
        } else {
            width = image.size.width * ratioVertical
            height = image.size.height * ratioVertical
        }
        
        let size = CGSize(width: width, height: height)
        
        var sourceBuffer = VImageBuffers.getSourceBuffer(for: cgImage)
        var destinationBuffer = VImageBuffers.getDestinationBuffer(
            for: cgImage,
            size: size,
            with: sourceBuffer
        )
        
        defer {
            sourceBuffer.free()
            destinationBuffer.free()
        }
        
        vImageScale_Planar8(
            &sourceBuffer,
            &destinationBuffer,
            nil,
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
    
    static func framePlanar8(image: UIImage, color: UIColor) -> UIImage {
        guard let cgImage = image.cgImage, cgImage.bitsPerPixel == 8 else {
            fatalError("Unable to get CGImage. Maybe it's not Planar8.")
        }
        
        let square = Int(Config.imageSize)
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        let rect = CGRect(
            x: Int(Double(square - width) / 2.0),
            y: Int(Double(square - height) / 2.0),
            width: width,
            height: height
        )
        
        guard let cgContext = CGContext(
            data: nil,
            width: square,
            height: square,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: square,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceGray(),
            bitmapInfo: cgImage.alphaInfo.rawValue
        ) else {
            fatalError("Unable to create CGContext.")
        }
        
        cgContext.setFillColor(color.cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: cgContext.width, height: cgContext.height))
        cgContext.draw(cgImage, in: rect)

        guard let newCgImage = cgContext.makeImage() else {
            fatalError("Unable to create CGImage from CGContext.")
        }

        return UIImage(cgImage: newCgImage)
    }
    
    static func ditherPlanar8(image: UIImage, progress: Binding<Float>) -> UIImage {
        guard let cgImage = image.cgImage, cgImage.bitsPerPixel == 8 else {
            fatalError("Unable to get CGImage. Maybe it's not Planar8.")
        }

        let data = Transformations.data(from: image)
        let riemersma = Riemersma(with: data, size: image.size, progress: progress)
        let ditheredData = riemersma.getDitheredImage()
        
        if let ditheredImage = Transformations.image(from: ditheredData, size: image.size) {
            return ditheredImage
        } else {
            return image
        }
    }
    
    static func image(from data: CFData, size: CGSize) -> UIImage? {
        guard let provider = CGDataProvider(data: data) else {
            fatalError("Failed to create CGDataProvider from raw data.")
        }
        
        guard let cgImage = CGImage(
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: Int(size.width),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            fatalError("Failed to create CGImage from CGImageProvider.")
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    static func data(from image: UIImage) -> CFMutableData {
        guard let cgImage = image.cgImage, let cgImageData = cgImage.dataProvider else {
            fatalError("Unable to get image data.")
        }
        
        let data = cgImageData.data
        let length = CFDataGetLength(data)
        
        return CFDataCreateMutableCopy(kCFAllocatorDefault, length, data)
    }
}
