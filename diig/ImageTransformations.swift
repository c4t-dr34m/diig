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
        
        if let ditheredImage = ImageTransformations.image(from: ditheredData, size: image.size) {
            return ditheredImage
        } else {
            return image
        }
    }
    
    static func luminance(of pixel: CGPoint, in image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else {
            return -1.0
        }
        
        let data = data(from: image)
        guard let pointer = CFDataGetBytePtr(data) else {
            return -1.0
        }
        
        let bpp = cgImage.bitsPerPixel
        if bpp == 8 {
            let pixelInfo: Int = ((Int(image.size.width) * Int(pixel.y)) + Int(pixel.x))
            
            return CGFloat(pointer[pixelInfo]) / CGFloat(255)
        } else if bpp == 32 {
            let pixelInfo: Int = ((Int(image.size.width) * Int(pixel.y)) + Int(pixel.x)) * 4
            
            return CGFloat(pointer[pixelInfo] + 1) / CGFloat(255) // green (?) channel
        } else {
            return -1.0
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
