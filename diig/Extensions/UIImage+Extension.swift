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
        ImageTransformations.convertToTrueMonochrome(image: self)
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
}
