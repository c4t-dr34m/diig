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
        Transformations.planar8(from: self)
    }
    
    func dither(progress: Binding<Float>) -> UIImage {
        Transformations.ditherPlanar8(image: self, progress: progress)
    }
    
    func scale(toFitSquare targetSize: Int) -> UIImage {
        Transformations.scalePlanar8(image: self, to: targetSize)
    }
    
    func frame(with color: UIColor) -> UIImage {
        Transformations.framePlanar8(image: self, color: color)
    }
}
