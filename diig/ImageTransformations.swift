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
    
    static func frame(image: UIImage, color: UIColor) -> UIImage {
        let square = Config.imageSize
        let width = image.size.width
        let height = image.size.height
        
        let size = CGSize(width: square, height: square)
        let rect = CGRect(
            x: (square - width) / 2,
            y: (square - height) / 2,
            width: width,
            height: height
        )

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        if let context = UIGraphicsGetCurrentContext() {
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: square, height: square))
        }
        
        image.draw(in: rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let newImage = newImage {
            return newImage
        } else {
            NSLog("Failed to resize image.")
            return image
        }
    }
    
    // outputs rgba8888 image no matter the input.56
    static func resize(image: UIImage, toFitSquare targetSize: Int) -> UIImage {
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
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let newImage = newImage {
            return newImage
        } else {
            NSLog("Failed to resize image.")
            return image
        }
    }
    
    // monochrome, but outputs still rgba8888 image.
    static func convertToMonochrome(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            NSLog("Failed to get image data for discoloration.")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)

        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(ciImage, forKey: "inputImage")
        filter?.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")
        filter?.setValue(1.0, forKey: "inputIntensity")

        guard let ciOutput = filter?.outputImage else {
            NSLog("Failed to filter image.")
            return image
        }

        if let cgOutput = CIContext().createCGImage(ciOutput, from: ciOutput.extent) {
            return UIImage(cgImage: cgOutput)
        }
        
        return image
    }
    
    // monochrome, planar8.
    static func convertToTrueMonochrome(image: UIImage) -> UIImage {
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
    
    static func dither(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage, cgImage.bitsPerPixel == 8 else {
            NSLog("Can't dither. The image is not Planar8.")
            return image
        }

        guard let data = ImageTransformations.data(from: image) else {
            NSLog("Failed to get image data for dithering.")
            return image
        }
        
        let riemersma = Riemersma(with: data, size: image.size)
        let ditheredData = riemersma.getDitheredImage()
        
        if let ditheredImage = ImageTransformations.image(from: ditheredData, original: image) {
            return ditheredImage
        } else {
            return image
        }
    }
    
    static func image(from data: CFData, original: UIImage) -> UIImage? {
        guard let originalCgImage = original.cgImage else {
            NSLog("Failed to create CGImage from original UIImage.")
            return nil
        }
        
        guard let provider = CGDataProvider(data: data) else {
            NSLog("Failed to create CGDataProvider from raw data.")
            return nil
        }
        
        guard let cgImage = CGImage(
            width: originalCgImage.width,
            height: originalCgImage.height,
            bitsPerComponent: originalCgImage.bitsPerComponent,
            bitsPerPixel: originalCgImage.bitsPerPixel,
            bytesPerRow: originalCgImage.bytesPerRow,
            space: originalCgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: originalCgImage.bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: originalCgImage.renderingIntent
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
    
    private static func getDestinationBuffer(for image: CGImage, with sourceBuffer: vImage_Buffer) -> vImage_Buffer {
        guard let destinationBuffer = try? vImage_Buffer(
            width: Int(sourceBuffer.width),
            height: Int(sourceBuffer.height),
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
