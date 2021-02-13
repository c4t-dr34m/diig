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
    
    @State private var image: UIImage? = nil
    @State private var imageDithered: UIImage? = nil
    @State private var frameColor: UIColor? = nil
    
    var body: some View {
        VStack {
            HStack {
                Button(action: presentCamera) {
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
                
                Button(action: presentGallery) {
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
            .padding(.bottom)
            .padding(.horizontal)
        }
        
        Spacer()
        
        imageView
        
        Spacer()
        
        HStack {
            Button(action: ditherImage) {
                HStack {
                    Image(systemName: "wand.and.rays").font(.system(size: 20))
                    Text("dither").font(.headline)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                .background(ditherButtonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(image == nil)

            Button(action: {
                self.frameColor = nil
            }) {
                HStack {
                    Image(systemName: "square.slash").font(.system(size: 20))
                }
                .frame(minWidth: 0, maxWidth: 50, minHeight: 0, maxHeight: 50)
                .background(frameButtonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(imageDithered == nil)

            Button(action: {
                self.frameColor = .white
            }) {
                HStack {
                    Image(systemName: "square.fill").font(.system(size: 20))
                }
                .frame(minWidth: 0, maxWidth: 50, minHeight: 0, maxHeight: 50)
                .background(frameButtonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(imageDithered == nil)
            
            Button(action: {
                self.frameColor = .black
            }) {
                HStack {
                    Image(systemName: "square").font(.system(size: 20))
                }
                .frame(minWidth: 0, maxWidth: 50, minHeight: 0, maxHeight: 50)
                .background(frameButtonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(imageDithered == nil)
            
            Button(action: shareImage) {
                HStack {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 20))
                    Text("share").font(.headline)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                .background(shareButtonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(imageDithered == nil)
        }
        .padding(.top)
        .padding(.horizontal)
    }
    
    private var imageView: some View {
        if let image = getFramedImage() {
            let imageView = Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            return AnyView(imageView)
        } else if let image = self.image {
            let imageView = Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            return AnyView(imageView)
        } else {
            let emptyView = EmptyView()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            return AnyView(emptyView)
        }
    }
    
    private var cameraButtonBackgroundColor: Color {
        isCameraAvailable ? .accentColor : .gray
    }
 
    
    private var ditherButtonBackgroundColor: Color {
        image != nil ? .accentColor : .gray
    }

    private var frameButtonBackgroundColor: Color {
        imageDithered != nil ? .accentColor : .gray
    }

    private var shareButtonBackgroundColor: Color {
        imageDithered != nil ? .accentColor : .gray
    }

    private func presentCamera() {
        isCameraPresented = true
    }
    
    private func presentGallery() {
        isGalleryPresented = true
    }
    
    private func getFramedImage() -> UIImage? {
        guard let imageDithered = self.imageDithered else {
            return nil
        }
        
        if let frameColor = self.frameColor {
            return imageDithered.frame(with: frameColor)
        } else {
            return imageDithered
        }
    }
    
    private func ditherImage() {
        guard let originalImage = self.image else {
            return
        }
        
        self.imageDithered = originalImage.dithered
    }
    
    private func shareImage() {
        guard let image = getFramedImage() else {
            return
        }
        
        let viewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        UIApplication.shared.windows.first?.rootViewController?.present(
            viewController,
            animated: true,
            completion: nil
        )
    }
}
