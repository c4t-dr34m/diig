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
    @State private var frameColor: UIColor = .black
    
    private var cameraButtonBackgroundColor: Color {
        isCameraAvailable ? .accentColor : .gray
    }
    
    private var imageView: some View {
        if let image = self.image {
            let framedImage = image.frame(with: self.frameColor)
            let imageView = Image(uiImage: framedImage)
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
    
    var body: some View {
        VStack {
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
            .padding(.bottom)
            .padding(.horizontal)
        }
        
        Spacer()
        
        imageView
        
        Spacer()
        
        HStack {
            Button(action: {
                guard let originalImage = self.image else {
                    return
                }
                
                let dithered = originalImage.dithered
                
                self.image = dithered
                self.imageDithered = dithered
            }) {
                HStack {
                    Image(systemName: "wand.and.rays").font(.system(size: 20))
                    Text("dither").font(.headline)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button(action: {
                self.frameColor = .black
            }) {
                HStack {
                    Image(systemName: "square.fill").font(.system(size: 20))
                }
                .frame(minWidth: 0, maxWidth: 50, minHeight: 0, maxHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button(action: {
                self.frameColor = .white
            }) {
                HStack {
                    Image(systemName: "square").font(.system(size: 20))
                }
                .frame(minWidth: 0, maxWidth: 50, minHeight: 0, maxHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button(action: {
                guard let image = self.image else {
                    return
                }
                
                let viewController = UIActivityViewController(
                    activityItems: [image.frame(with: self.frameColor)],
                    applicationActivities: nil
                )
                UIApplication.shared.windows.first?.rootViewController?.present(
                    viewController,
                    animated: true,
                    completion: nil
                )
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 20))
                    Text("share").font(.headline)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.top)
        .padding(.horizontal)
    }
}

private extension View {
    func log(_ message: String) -> some View {
        NSLog(message)
        
        return EmptyView()
    }
}
