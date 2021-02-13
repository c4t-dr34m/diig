//
//  Riemersma.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import UIKit

private enum Direction {
    case none
    case left
    case right
    case up
    case down
}

final class Riemersma {
    
    private static let size = 48 // number of pixels remembered while traversing the image
    private static let weightDiff = 8 // basically contrast of the resulting image
    
    private let imageData: CFMutableData
    private let imageDataPointer: UnsafeMutablePointer<UInt8>
    private let imageSize: CGSize
    
    private var dithered = false
    
    private var currentPosition: CGPoint = CGPoint(x: 0.0, y: 0.0)
    
    private var weights = Array<CGFloat>(repeating: 0.0, count: size)
    private var errors = Array<CGFloat>(repeating: 0.0, count: size)
    
    public init(with data: CFMutableData, size: CGSize) {
        self.imageData = data
        self.imageSize = size
        self.imageDataPointer = CFDataGetMutableBytePtr(imageData)
    }
    
    public func getDitheredImage() -> CFMutableData {
        guard !dithered else {
            return imageData
        }
        
        initWeights()
        
        let size = max(imageSize.width, imageSize.height)
        var level = Int(log2(size))

        if ((1 << level) < Int(size)) {
            level += 1
        }
        
        if level > 0 {
            hilbert(level: level, direction: .up)
        }
        
        move(to: .none)
        dithered = true
        
        return imageData
    }
    
    private func initWeights() {
        let m: CGFloat = CGFloat(exp(log(Double(Riemersma.weightDiff)) / Double(Riemersma.size - 1)))
        var v: CGFloat = 1.0
        
        for i in 0...(Riemersma.size - 1) {
            weights[i] = v + 0.5
            v *= m
        }
    }
    
    private func getLuminance(for pixel: CGPoint) -> CGFloat {
        let pixelInfo: Int = ((Int(imageSize.width) * Int(pixel.y)) + Int(pixel.x)) * 4
        
        return CGFloat(imageDataPointer[pixelInfo]) / CGFloat(255)
    }
    
    private func saveLuminance(_ luminance: CGFloat, for pixel: CGPoint) {
        let pixelInfo: Int = ((Int(imageSize.width) * Int(pixel.y)) + Int(pixel.x)) * 4

        imageDataPointer[pixelInfo] = UInt8(luminance * CGFloat(255))
        imageDataPointer[pixelInfo + 1] = UInt8(luminance * CGFloat(255))
        imageDataPointer[pixelInfo + 2] = UInt8(luminance * CGFloat(255))
        imageDataPointer[pixelInfo + 3] = 255 // opacity
    }
    
    private func dither(_ luminance: CGFloat) -> CGFloat {
        var newLuminance: CGFloat
        var error: CGFloat = 0.0
        
        for i in 0...(Riemersma.size - 1) {
            error += errors[i] * weights[i]
        }
        
        newLuminance = luminance + (error / CGFloat(Riemersma.weightDiff))
        newLuminance = (newLuminance >= 0.5) ? 1.0 : 0.0
        
        errors.remove(at: 0)
        errors.append(luminance - newLuminance)
        
        if errors.count != Riemersma.size {
            NSLog("Errors array doesn't contain correct number of items: \(errors.count)")
        }
        
        return newLuminance
    }
    
    private func move(to direction: Direction) {
        if (currentPosition.x >= 0 && currentPosition.x < imageSize.width
                && currentPosition.y >= 0 && currentPosition.y < imageSize.height
        ) {
            var luminance = getLuminance(for: currentPosition)
            luminance = dither(luminance)
            saveLuminance(luminance, for: currentPosition)
        }
        
        switch (direction) {
        case .left:
            currentPosition.x -= 1
        case .right:
            currentPosition.x += 1
        case .up:
            currentPosition.y -= 1
        case .down:
            currentPosition.y += 1
        case .none:
            break
        }
    }
    
    private func hilbert(level: Int, direction: Direction) {
        if level == 1 {
            switch (direction) {
            case .left:
                move(to: .right)
                move(to: .down)
                move(to: .left)
            case .right:
                move(to: .left)
                move(to: .up)
                move(to: .right)
            case .up:
                move(to: .down)
                move(to: .right)
                move(to: .up)
            case .down:
                move(to: .up)
                move(to: .left)
                move(to: .down)
            case .none:
                break
            }
        } else {
            switch (direction) {
            case .left:
                hilbert(level: level - 1, direction: .up)
                move(to: .right)
                hilbert(level: level - 1, direction: .left)
                move(to: .down)
                hilbert(level: level - 1, direction: .left)
                move(to: .left)
                hilbert(level: level - 1, direction: .down)
            case .right:
                hilbert(level: level - 1, direction: .down)
                move(to: .left)
                hilbert(level: level - 1, direction: .right)
                move(to: .up)
                hilbert(level: level - 1, direction: .right)
                move(to: .right)
                hilbert(level: level - 1, direction: .up)
            case .up:
                hilbert(level: level - 1, direction: .left)
                move(to: .down)
                hilbert(level: level - 1, direction: .up)
                move(to: .right)
                hilbert(level: level - 1, direction: .up)
                move(to: .up)
                hilbert(level: level - 1, direction: .right)
            case .down:
                hilbert(level: level - 1, direction: .right)
                move(to: .up)
                hilbert(level: level - 1, direction: .down)
                move(to: .left)
                hilbert(level: level - 1, direction: .down)
                move(to: .down)
                hilbert(level: level - 1, direction: .left)
            case .none:
                break
            }
        }
    }
}
