//
//  UIImage+Extension.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import SwiftUI
import UIKit

public extension UIImage {
    
    var planar: UIImage {
        ImageTransformations.planar8(from: self)
    }
    
    func dither(progress: Binding<Float>) -> UIImage {
        ImageTransformations.ditherPlanar8(image: self, progress: progress)
    }
    
    func scale(toFitSquare targetSize: Int) -> UIImage {
        ImageTransformations.scalePlanar8(image: self, to: targetSize)
    }
    
    func frame(with color: UIColor) -> UIImage {
        ImageTransformations.framePlanar8(image: self, color: color)
    }
}
