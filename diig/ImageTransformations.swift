//
//  ImageTransformations.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit

final class ImageTransformations {
    
    static func convertToMonochrome(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)

        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(ciImage, forKey: "inputImage")
        filter?.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")
        filter?.setValue(1.0, forKey: "inputIntensity")

        guard let ciOutput = filter?.outputImage else {
            return image
        }

        if let cgOutput = CIContext().createCGImage(ciOutput, from: ciOutput.extent) {
            return UIImage(cgImage: cgOutput)
        }
        
        return image
    }
    
    static func getPixelLuminance(image: UIImage, pos: CGPoint) throws -> Float {
        guard let cgImage = image.cgImage else {
            throw ImageTransformationError.cgImage
        }
        
        guard let cgImageData = cgImage.dataProvider else {
            throw ImageTransformationError.cgImageDataProvider
        }
        
        guard let data = cgImageData.data else {
            throw ImageTransformationError.cgImageData
        }
        
        do {
            return try getPixelLuminance(data: data, imageWidth: Int(image.size.width), pos: pos)
        } catch {
            throw error
        }
    }
    
    static func getPixelLuminance(data: CFData, imageWidth: Int, pos: CGPoint) throws -> Float {
        let pixelData: UnsafePointer<UInt8> = CFDataGetBytePtr(data)
        let pixelInfo: Int = ((imageWidth * Int(pos.y)) + Int(pos.x)) * 4
        
        let r = CGFloat(pixelData[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(pixelData[pixelInfo + 1]) / CGFloat(255.0)
        let b = CGFloat(pixelData[pixelInfo + 2]) / CGFloat(255.0)
        let a = CGFloat(pixelData[pixelInfo + 3]) / CGFloat(255.0)
        
        guard a == 1 else {
            throw ImageTransformationError.pixelTransparent
        }
        
        guard r == g && g == b else {
            throw ImageTransformationError.pixelNotMonochrome
        }
        
        return Float(r)
    }
}

public enum ImageTransformationError: Error {
    case cgImage
    case cgImageDataProvider
    case cgImageData
    
    case pixelTransparent
    case pixelNotMonochrome
}

public extension UIImage {
    var monochrome: UIImage {
        ImageTransformations.convertToMonochrome(image: self)
    }
    
    func pixelLuminance(x: Int, y: Int) -> Float {
        do {
            return try ImageTransformations.getPixelLuminance(image: self, pos: CGPoint(x: x, y: y))
        } catch {
            NSLog("Cannot obtain pixel luminosity: \(error.localizedDescription)")
        }
        
        return -1.0
    }
}
