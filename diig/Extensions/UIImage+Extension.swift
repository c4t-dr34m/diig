//
//  UIImage+Extension.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit

public extension UIImage {
    
    var monochrome: UIImage {
        ImageTransformations.convertToMonochrome(image: self)
    }
    
    var dithered: UIImage {
        ImageTransformations.dither(image: self)
    }
    
    func resize(toFitSquare targetSize: Int) -> UIImage {
        ImageTransformations.resize(image: self, toFitSquare: targetSize)
    }
    
    func frame(with color: UIColor) -> UIImage {
        ImageTransformations.frame(image: self, color: color)
    }
    
    func pixelLuminance(x: Int, y: Int) -> CGFloat {
        do {
            return try ImageTransformations.getLuminance(for: CGPoint(x: x, y: y), from: self)
        } catch {
            NSLog("Cannot obtain pixel luminosity: \(error.localizedDescription)")
        }
        
        return -1.0
    }
}
