//
//  ImageTransformations.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit
import Accelerate

public enum ImageTransformationError: Error {
    case noImageData
    case pixelNotMonochrome
}

final class ImageTransformations {

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
        
        var sourceBuffer = getSourceBuffer(for: cgImage)
        var destinationBuffer = getDestinationBuffer(for: cgImage, with: sourceBuffer)
        
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
        
        var sourceBuffer = getSourceBuffer(for: cgImage)
        var destinationBuffer = getDestinationBuffer(for: cgImage, size: size, with: sourceBuffer)
        
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
    
    static func ditherPlanar8(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage, cgImage.bitsPerPixel == 8 else {
            fatalError("Unable to get CGImage. Maybe it's not Planar8.")
        }

        guard let data = ImageTransformations.data(from: image) else {
            NSLog("Failed to get image data for dithering.")
            return image
        }
        
        let riemersma = Riemersma(with: data, size: image.size)
        let ditheredData = riemersma.getDitheredImage()
        
        if let ditheredImage = ImageTransformations.image(from: ditheredData, size: image.size) {
            return ditheredImage
        } else {
            return image
        }
    }
    
    static func image(from data: CFData, size: CGSize) -> UIImage? {
        guard let provider = CGDataProvider(data: data) else {
            NSLog("Failed to create CGDataProvider from raw data.")
            return nil
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
            NSLog("Failed to create CGImage from CGImageProvider.")
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    static func data(from image: UIImage) -> CFMutableData? {
        guard let cgImage = image.cgImage, let cgImageData = cgImage.dataProvider else {
            return nil
        }
        
        let data = cgImageData.data
        let length = CFDataGetLength(data)
        
        return CFDataCreateMutableCopy(kCFAllocatorDefault, length, data)
    }
    
    private static func getSourceBuffer(for image: CGImage) -> vImage_Buffer {
        let format = format(of: image)
        
        guard
            let sourceImageBuffer = try? vImage_Buffer(
                cgImage: image,
                format: format
            ) else {
            fatalError("Unable to create source buffer.")
        }
        
        return sourceImageBuffer
    }
    
    private static func getDestinationBuffer(
        for image: CGImage,
        size: CGSize? = nil,
        with sourceBuffer: vImage_Buffer
    ) -> vImage_Buffer {
        let width: Int
        let height: Int
        if let size = size {
            width = Int(size.width)
            height = Int(size.height)
        } else {
            width = Int(sourceBuffer.width)
            height = Int(sourceBuffer.height)
        }
        
        guard let destinationBuffer = try? vImage_Buffer(
            width: width,
            height: height,
            bitsPerPixel: 8
        ) else {
            fatalError("Unable to create destination buffers.")
        }
        
        return destinationBuffer
    }
    
    static func format(of image: CGImage) -> vImage_CGImageFormat {
        guard let format = vImage_CGImageFormat(cgImage: image) else {
            fatalError("Unable to get CGImage format.")
        }
        
        return format
    }
}
