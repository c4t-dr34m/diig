//
//  ImagePicker.swift
//  diig
//
//  Created by Radovan Paška on 12.02.2021.
//

import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
        
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
 
    func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImagePicker>
    ) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator

        return imagePicker
    }

    func makeCoordinator() -> ImagePickerCoordinator {
        ImagePickerCoordinator(image: $image, isPresented: $isPresented)
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: UIViewControllerRepresentableContext<ImagePicker>
    ) {
        // noop
    }
}
