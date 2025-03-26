//
//  VImageBuffers.swift
//  diig
//
//  Created by Radovan Paška on 15.02.2021.
//

import Foundation
import UIKit
import Accelerate

final class VImageBuffers {
	static func getSourceBuffer(for image: CGImage) -> vImage_Buffer {
		let format = format(of: image)

		guard
			let sourceImageBuffer = try? vImage_Buffer(
				cgImage: image,
				format: format
			) else {
			fatalError("Unable to create source buffer.")
		}

		return sourceImageBuffer
	}

	static func getDestinationBuffer(
		for image: CGImage,
		size: CGSize? = nil,
		with sourceBuffer: vImage_Buffer
	) -> vImage_Buffer {
		let width: Int
		let height: Int
		if let size = size {
			width = Int(size.width)
			height = Int(size.height)
		} else {
			width = Int(sourceBuffer.width)
			height = Int(sourceBuffer.height)
		}

		guard let destinationBuffer = try? vImage_Buffer(
			width: width,
			height: height,
			bitsPerPixel: 8
		) else {
			fatalError("Unable to create destination buffers.")
		}

		return destinationBuffer
	}

	static func format(of image: CGImage) -> vImage_CGImageFormat {
		guard let format = vImage_CGImageFormat(cgImage: image) else {
			fatalError("Unable to get CGImage format.")
		}

		return format
	}
}
