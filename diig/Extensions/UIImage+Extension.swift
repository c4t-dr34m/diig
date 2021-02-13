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
    
    func pixelLuminance(x: Int, y: Int) -> Float {
        do {
            return try ImageTransformations.getPixelLuminance(image: self, pos: CGPoint(x: x, y: y))
        } catch {
            NSLog("Cannot obtain pixel luminosity: \(error.localizedDescription)")
        }
        
        return -1.0
    }
}
