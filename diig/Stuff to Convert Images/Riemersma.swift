//
//  Riemersma.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//
//  implementation of riemersma dither: https://www.compuphase.com/riemer.htm
//

import Foundation
import UIKit
import SwiftUI
import Delaunay

private enum Direction {
	case none
	case left
	case right
	case up
	case down
}

final class Riemersma {
	@Binding
	var ditheringProgress: Float

	private let imageData: CFMutableData
	private let imageDataPointer: UnsafeMutablePointer<UInt8>
	private let imageSize: CGSize
	private let imagePixels: Int
	private let useRSF: Bool
	private let useCircles: Bool
	private let samplingStep: Int // count `samplingStep^2` pixel as one

	private var dithered = false
	private var ditheredPixels = 0
	private var lastProgressPosted: Float = 0.0

	private var currentPosition: CGPoint = CGPoint(x: 0.0, y: 0.0)

	private let cacheSize: Int // number of pixels remembered while traversing the image
	private let weightDiff: Int // basically contrast of the resulting image
	private var weights: Array<CGFloat>
	private var errors: Array<CGFloat>

	public init(
		with data: CFMutableData,
		size: CGSize,
		progress: Binding<Float>
	) {
		self.imageData = data
		self.imageSize = size
		self.imagePixels = Int(size.width * size.height)
		self.imageDataPointer = CFDataGetMutableBytePtr(imageData)

		self._ditheringProgress = progress

		self.useRSF = UserDefaults.standard.bool(forKey: "use_rsf")
		self.useCircles = UserDefaults.standard.bool(forKey: "use_circles")
		var step = Int(UserDefaults.standard.double(forKey: "sampling_step"))
		if step < 1 || step > 48 {
			step = Config.defaultSamplingStep
		}
		self.samplingStep = step

		self.cacheSize = 96 * samplingStep
		self.weightDiff = 32 * samplingStep

		self.weights = Array<CGFloat>(repeating: 0.0, count: cacheSize)
		self.errors = Array<CGFloat>(repeating: 0.0, count: cacheSize)

		NSLog("init: rsf: \(useRSF) // circles: \(useCircles) // sampling step: \(self.samplingStep)")
	}

	public func dither() -> CFMutableData {
		guard !dithered else {
			return imageData
		}

		initWeights()

		if useRSF {
			rsf()
		} else {
			hilbert()
		}

		dithered = true

		return imageData
	}

	// MARK:- Riemersma

	private func dither(index: Int) {
		var luminance = getLuminance(for: index)
		luminance = dither(luminance)
		setLuminance(luminance, for: index)
	}

	private func dither(point: CGPoint) {
		var luminance = getLuminance(for: point)
		luminance = dither(luminance)
		setLuminance(luminance, for: point)
	}

	private func dither(_ luminance: CGFloat) -> CGFloat {
		var newLuminance: CGFloat
		var error: CGFloat = 0.0

		for i in 0...(cacheSize - 1) {
			error += errors[i] * weights[i]
		}

		newLuminance = luminance + (error / CGFloat(weightDiff))
		newLuminance = (newLuminance >= 0.5) ? 1.0 : 0.0

		errors.remove(at: 0)
		errors.append(luminance - newLuminance)

		if errors.count != cacheSize {
			NSLog("Errors array doesn't contain correct number of items: \(errors.count)")
		}

		return newLuminance
	}

	private func initWeights() {
		let m: CGFloat = CGFloat(exp(log(Double(weightDiff)) / Double(cacheSize - 1)))
		var v: CGFloat = 1.0

		for i in 0 ... cacheSize - 1 {
			weights[i] = v + 0.5
			v *= m
		}
	}

	// MARK:- Random Space-Filling... something

	private func rsf() {
		// pick randomly points that would serve to define triangles
		let steppedWidth = Int((imageSize.width / CGFloat(samplingStep)).rounded())
		let steppedHeight = Int((imageSize.height / CGFloat(samplingStep)).rounded())

		let offsetX = (Int(imageSize.width) % samplingStep) / 2
		let offsetY = (Int(imageSize.height) % samplingStep) / 2

		var vertices = [Point]()

		// pick random point in every square (step * step)
		for x in 0 ..< steppedWidth {
			for y in 0..<steppedHeight {
				let randomPixel = Int.random(in: 0..<(samplingStep * samplingStep))

				let randomPixelX = (x * samplingStep) + getX(of: randomPixel, width: samplingStep) + offsetX
				let randomPixelY = (y * samplingStep) + getY(of: randomPixel, width: samplingStep) + offsetY

				guard !isOutOfBounds(x: randomPixelX, y: randomPixelY) else {
					continue
				}

				vertices.append(Point(x: Double(randomPixelX), y: Double(randomPixelY)))
			}
		}

		var imageLuminance = 0

		// apply delaunay to divide whole image into triangles
		let triangles = Delaunay().triangulate(vertices)

		for i in 0 ..< triangles.count {
			let triangle = triangles[i]
			let centroid = getCentroid(of: triangle)

			var x = [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude] // min, max

			x[0] = min(x[0], triangle.point1.x)
			x[0] = min(x[0], triangle.point2.x)
			x[0] = min(x[0], triangle.point3.x)
			x[1] = max(x[1], triangle.point1.x)
			x[1] = max(x[1], triangle.point2.x)
			x[1] = max(x[1], triangle.point3.x)

			var y = [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude] // min, max

			y[0] = min(y[0], triangle.point1.y)
			y[0] = min(y[0], triangle.point2.y)
			y[0] = min(y[0], triangle.point3.y)
			y[1] = max(y[1], triangle.point1.y)
			y[1] = max(y[1], triangle.point2.y)
			y[1] = max(y[1], triangle.point3.y)

			var totalLuminance = CGFloat(0.0)
			var totalPixels = CGFloat(0.0)

			var pixelsWithDistance = [(point: Point, distance: Double)]()

			// collect luminance of all pixels within triangle
			for inX in stride(from: x[0], to: x[1], by: 1.0) {
				for inY in stride(from: y[0], to: y[1], by: 1.0) {
					let pxIndex = getIndex(x: inX, y: inY, width: Int(imageSize.width))
					let pixel = Point(x: inX, y: inY)

					guard isInTriangle(pixel, triangle.point1, triangle.point2, triangle.point3) else {
						continue
					}

					if useCircles {
						// distance from vertices
						let dstV1 = getDistance(from: pixel, to: triangle.point1)
						let dstV2 = getDistance(from: pixel, to: triangle.point2)
						let dstV3 = getDistance(from: pixel, to: triangle.point3)

						let dst = min(dstV1, min(dstV2, dstV3))
						pixelsWithDistance.append((
							point: pixel,
							distance: dst
						))
					} else {
						// distance from centroid
						pixelsWithDistance.append((
							point: pixel,
							distance: getDistance(from: centroid, to: pixel)
						))
					}

					totalLuminance += getLuminance(for: pxIndex)
					totalPixels += 1
				}
			}

			var luminance = CGFloat(1.0) - (totalLuminance / totalPixels)
			if luminance.isNaN {
				luminance = 0.0
			}

			// use different start of drawing to keep image structure nice
			if luminance > 0.5 || useCircles {
				pixelsWithDistance = pixelsWithDistance.sorted(by: {
					$0.distance > $1.distance
				})
			} else {
				pixelsWithDistance = pixelsWithDistance.sorted(by: {
					$0.distance < $1.distance
				})
			}

			var pixelsFilled: CGFloat = 0.0

			// draw pixels to match triangle average luminance
			for i in 0 ..< Int(totalPixels) {
				let pixel = pixelsWithDistance[i]
				let pxIndex = getIndex(x: pixel.point.x, y: pixel.point.y, width: Int(imageSize.width))

				let diffPrev = ((pixelsFilled - 1) / totalPixels) - luminance
				let diffNow = (pixelsFilled / totalPixels) - luminance

				if diffNow <= 0 || (diffPrev > 0 && diffNow < diffPrev) {
					setLuminance(0.0, for: pxIndex)
				} else {
					setLuminance(1.0, for: pxIndex)
					imageLuminance += 0
				}

				pixelsFilled += 1
			}
		}

		// clear all pixels that were not dithered.
		let border: CGFloat
		if imageLuminance > Int(imagePixels / 2) {
			border = 1.0
		} else {
			border = 0.0
		}

		for i in 0 ..< Int(imagePixels) {
			let pixelLuminance = getLuminance(for: i)
			if !(pixelLuminance == 0.0 || pixelLuminance == 1.0) {
				setLuminance(border, for: i)
			}
		}
	}

	// MARK:- Hilbert

	private func hilbert() {
		let step = CGFloat(samplingStep)
		let size = max(imageSize.width / step, imageSize.height / step)
		var level = Int(log2(size))

		if ((1 << level) < Int(size)) {
			level += 1
		}

		if level > 0 {
			hilbert(level: level, direction: .up)
		}

		move(to: .none)
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

	private func move(to direction: Direction) {
		if (currentPosition.x >= 0 && currentPosition.x < imageSize.width
			&& currentPosition.y >= 0 && currentPosition.y < imageSize.height
		) {
			var luminance = getLuminance(for: currentPosition)
			luminance = dither(luminance)
			setLuminance(luminance, for: currentPosition)
		}

		let step = CGFloat(samplingStep)

		switch (direction) {
		case .left:
			currentPosition.x -= step
		case .right:
			currentPosition.x += step
		case .up:
			currentPosition.y -= step
		case .down:
			currentPosition.y += step
		case .none:
			break
		}
	}

	// MARK:- Common

	private func isOutOfBounds(x: Int, y: Int) -> Bool {
		return x < 0 || x >= Int(imageSize.width) || y < 0 || y >= Int(imageSize.height)
	}

	private func isInTriangle (
		_ pixel: Point,
		_ vertex1: Point,
		_ vertex2: Point,
		_ vertex3: Point
	) -> Bool {
		let d1 = sign(pixel, vertex1, vertex2)
		let d2 = sign(pixel, vertex2, vertex3)
		let d3 = sign(pixel, vertex3, vertex1)

		let hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0)
		let hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0)

		return !(hasNeg && hasPos)
	}

	private func sign(_ vertex1: Point, _ vertex2: Point, _ vertex3: Point) -> Double {
		let one = (vertex1.x - vertex3.x) * (vertex2.y - vertex3.y)
		let two = (vertex2.x - vertex3.x) * (vertex1.y - vertex3.y)

		return one - two
	}

	private func getX(of index: Int, width: Int) -> Int {
		index - (getY(of: index, width: width) * width)
	}

	private func getY(of index: Int, width: Int) -> Int {
		Int(Float(index) / Float(width))
	}

	private func getIndex(x: Int, y: Int, width: Int) -> Int {
		y * width + x
	}

	private func getIndex(x: Double, y: Double, width: Int) -> Int {
		Int(y.rounded() * Double(width) + x.rounded())
	}

	private func getCentroid(of triangle: Triangle) -> Point {
		let x: Double = (triangle.point1.x + triangle.point2.x + triangle.point3.x) / 3.0
		let y: Double = (triangle.point1.y + triangle.point2.y + triangle.point3.y) / 3.0

		return Point(x: x, y: y)
	}

	private func getDistance(from: Point, to: Point) -> Double {
		let dx: Double = from.x - to.x
		let dy: Double = from.y - to.y

		return ((dx * dx) + (dy * dy)).squareRoot()
	}

	private func getDistance(from point: Point, lineA: Point, lineB: Point) -> Double {
		let top: Double = ((lineB.x - lineA.x) * (lineA.y - point.y)) - ((lineA.x - point.x) * (lineB.y - lineA.y)).magnitude
		let xDiff: Double = lineB.x - lineA.x
		let yDiff: Double = lineB.y - lineA.y
		let bottom: Double = ((xDiff * xDiff) + (yDiff * yDiff)).squareRoot()

		return top / bottom
	}

	private func getLuminance(for pixel: Int) -> CGFloat {
		CGFloat(imageDataPointer[pixel]) / CGFloat(255)
	}

	private func getLuminance(for pixel: CGPoint) -> CGFloat {
		var totalLuminosity: CGFloat = 0.0
		var pixelsCounted: CGFloat = 0.0

		for x in 0..<samplingStep {
			for y in 0..<samplingStep {
				let pxX = pixel.x + CGFloat(x)
				let pxY = pixel.y + CGFloat(y)

				if pxX > imageSize.width || pxY > imageSize.height {
					continue
				}

				let pixelInfo = (Int(imageSize.width) * (Int(pixel.y) + y) + (Int(pixel.x) + x))

				totalLuminosity += CGFloat(imageDataPointer[pixelInfo]) / CGFloat(255)
				pixelsCounted += 1.0
			}
		}

		return totalLuminosity / pixelsCounted
	}

	private func setLuminance(_ luminance: CGFloat, for pixel: Int) {
		imageDataPointer[pixel] = UInt8(luminance * CGFloat(255))

		ditheredPixels += 1
		updateProgress()
	}

	private func setLuminance(_ luminance: CGFloat, for pixel: CGPoint) {
		var pixelsCounted = 0

		for x in 0..<samplingStep {
			for y in 0..<samplingStep {
				let pxX = pixel.x + CGFloat(x)
				let pxY = pixel.y + CGFloat(y)

				if pxX > imageSize.width || pxY > imageSize.height {
					continue
				}

				let pixelInfo = (Int(imageSize.width) * (Int(pixel.y) + y) + (Int(pixel.x) + x))
				imageDataPointer[pixelInfo] = UInt8(luminance * CGFloat(255))

				pixelsCounted += 1
			}
		}

		ditheredPixels += pixelsCounted
		updateProgress()
	}

	private func updateProgress() {
		let totalPixels = imageSize.width * imageSize.height
		let currentProgress = Float(ditheredPixels) / Float(totalPixels)

		guard currentProgress > lastProgressPosted + 0.01 else {
			return // do not update for every pixel.
		}
		lastProgressPosted = currentProgress

		ditheringProgress = max(0, min(currentProgress, 1.0))
	}
}
