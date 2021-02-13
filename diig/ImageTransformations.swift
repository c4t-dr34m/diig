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
    
    static func convertToDithered(image: UIImage) -> UIImage {
        // todo: dithering
        
        return image
    }
    
    static func getData(image: UIImage) -> CFData? {
        guard let cgImage = image.cgImage, let cgImageData = cgImage.dataProvider else {
            return nil
        }
        
        return cgImageData.data
    }
    
    static func getPixelLuminance(image: UIImage, pos: CGPoint) throws -> Float {
        guard let data = getData(image: image) else {
            throw ImageTransformationError.noImageData
        }
        
        let pixelData: UnsafePointer<UInt8> = CFDataGetBytePtr(data)
        let pixelInfo: Int = ((Int(image.size.width) * Int(pos.y)) + Int(pos.x)) * 4
        
        let r = CGFloat(pixelData[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(pixelData[pixelInfo + 1]) / CGFloat(255.0)
        let b = CGFloat(pixelData[pixelInfo + 2]) / CGFloat(255.0)
        // let a = CGFloat(pixelData[pixelInfo + 3]) / CGFloat(255.0)
        
        guard r == g && g == b else {
            throw ImageTransformationError.pixelNotMonochrome
        }
        
        return Float(r)
    }
}
