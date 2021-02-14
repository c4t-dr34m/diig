//
//  Config.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit

public struct Config {
    
    public static let defaultSamplingStep = 2
    
    public static let imageSize = CGFloat(1080)
    public static let frameSize = CGFloat(0.01)
    
    public static  let imageInset = imageSize - (imageSize * frameSize)
}
