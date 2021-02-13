//
//  ContentView.swift
//  diig
//
//  Created by Radovan Paška on 12.02.2021.
//

import SwiftUI

struct ImageView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    @State private var isGalleryPresented = false
    @State private var isCameraPresented = false
    @State private var image = UIImage()
    
    var cameraButtonBackgroundColor: Color {
        isCameraAvailable ? .accentColor : .gray
    }
    
    var body: some View {
        log("Pixel luminance: \(image.monochrome.pixelLuminance(x: Int(image.size.width / 2), y: Int(image.size.height / 2)))")
        
        VStack {
            Image(uiImage: self.image.monochrome)
                .resizable()
                .scaledToFit()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            HStack {
                Button(action: {self.isCameraPresented = true}) {
                    HStack {
                        Image(systemName: "camera").font(.system(size: 20))
                        Text("camera").font(.headline)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                    .background(cameraButtonBackgroundColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!isCameraAvailable)
                .sheet(isPresented: $isCameraPresented) {
                    ImagePicker(selectedImage: self.$image, sourceType: .camera)
                }
                
                Button(action: {self.isGalleryPresented = true}) {
                    HStack {
                        Image(systemName: "photo").font(.system(size: 20))
                        Text("photo library").font(.headline)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .sheet(isPresented: $isGalleryPresented) {
                    ImagePicker(selectedImage: self.$image, sourceType: .photoLibrary)
                }
            }
            .padding(.horizontal)
        }
    }
}

private extension View {
    func log(_ message: String) -> some View {
        NSLog(message)
        
        return EmptyView()
    }
}
