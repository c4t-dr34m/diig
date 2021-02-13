//
//  ImagePickerCoordinator.swift
//  diig
//
//  Created by Radovan Paška on 13.02.2021.
//

import Foundation
import SwiftUI

final class ImagePickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
 
    var parent: ImagePicker
    
    init(_ parent: ImagePicker) {
        self.parent = parent
    }
 
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            parent.selectedImage = image
        }
 
        parent.presentationMode.wrappedValue.dismiss()
    }
}
