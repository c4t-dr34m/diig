//
//  ImageTransformations.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit

public enum ImageTransformationError: Error {
    case noImageData
    case pixelNotMonochrome
}

final class ImageTransformations {
    
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
    
    static func dither(image: UIImage) -> UIImage {
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
        guard let provider = CGDataProvider(data: data) else {
            NSLog("Failed to create CGDataProvider from raw data.")
            return nil
        }
        
        guard let originalCgImage = original.cgImage else {
            NSLog("Failed to create CGImage from original UIImage.")
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
    
    static func getLuminance(for pixel: CGPoint, from image: UIImage) throws -> CGFloat {
        guard let data = ImageTransformations.data(from: image) else {
            throw ImageTransformationError.noImageData
        }
        
        let pixelData: UnsafePointer<UInt8> = CFDataGetBytePtr(data)
        let pixelInfo: Int = ((Int(image.size.width) * Int(pixel.y)) + Int(pixel.x)) * 4
        
        let r = CGFloat(pixelData[pixelInfo]) / CGFloat(255)
        let g = CGFloat(pixelData[pixelInfo + 1]) / CGFloat(255)
        let b = CGFloat(pixelData[pixelInfo + 2]) / CGFloat(255)
        // let a = CGFloat(pixelData[pixelInfo + 3]) / CGFloat(255)
        
        guard r == g && g == b else {
            throw ImageTransformationError.pixelNotMonochrome
        }
        
        return r
    }
}
