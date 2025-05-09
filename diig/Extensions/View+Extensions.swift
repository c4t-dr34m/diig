//
//  View+Extension.swift
//  diig
//
//  Created by Radovan Paška on 18.02.2021.
//

import Foundation
import SwiftUI

struct RoundedCorner: Shape {
	var radius: CGFloat = .infinity
	var corners: UIRectCorner = .allCorners

	func path(in rect: CGRect) -> Path {
		let path = UIBezierPath(
			roundedRect: rect,
			byRoundingCorners: corners,
			cornerRadii: CGSize(width: radius, height: radius)
		)

		return Path(path.cgPath)
	}
}

extension View {
	func cornerRadius(
		_ radius: CGFloat,
		corners: UIRectCorner
	) -> some View {
		clipShape(RoundedCorner(radius: radius, corners: corners))
	}
}
