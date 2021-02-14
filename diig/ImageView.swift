//
//  ContentView.swift
//  diig
//
//  Created by Radovan Paška on 12.02.2021.
//

import SwiftUI

struct ImageView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isPickerPresented = false
    @State private var isDithering = false
    @State private var isDitheringAvailable = true
    
    @State private var image: UIImage? = nil
    @State private var imageDithered: UIImage? = nil
    @State private var frameColor: UIColor? = .white
    
    @State private var timer: Timer? = nil
    
    var body: some View {
        log {
            if let image = self.image {
                return "image dimensions: \(image.size.width)×\(image.size.height) px"
            } else {
                return "image dimensions: image not yet loaded"
            }
        }

        NavigationView {
            ZStack {
                VStack {
                    Spacer()
                    imageView
                    Spacer()
                }
                .blur(radius: isDithering ? 10 : 0)
                .navigationBarTitle(Text("diig"), displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: ToolbarItemPlacement.primaryAction) {
                        Button(action: {
                            image = nil
                            imageDithered = nil
                            
                            isDitheringAvailable = true
                            isPickerPresented = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: ditherImage) { () -> Image in
                            if isDithering {
                                return Image(systemName: "hourglass")
                            } else {
                                return Image(systemName: "wand.and.stars")
                            }
                        }
                        .disabled(image == nil || !isDitheringAvailable || isDithering)
                        
                        Spacer()
                        
                        HStack {
                            Button(action: {
                                if self.frameColor == nil || self.frameColor == .white {
                                    self.frameColor = .black
                                } else {
                                    self.frameColor = .white
                                }
                            }) {
                                if self.frameColor == nil || self.frameColor == .white {
                                    Image(systemName: "circle.righthalf.fill")
                                } else {
                                    Image(systemName: "circle.lefthalf.fill")
                                }
                            }
                            .disabled(imageDithered == nil)
                            
                            Divider()
                            
                            Button(action: {
                                self.frameColor = nil
                            }) {
                                if self.frameColor == nil || self.frameColor == .white {
                                    Image(systemName: "slash.circle.fill")
                                } else {
                                    Image(systemName: "slash.circle")
                                }
                                
                            }
                            .frame(minWidth: 0, maxWidth: 48, minHeight: 0)
                            .disabled(imageDithered == nil)
                        }
                        
                        Spacer()
                        
                        Button(action: shareImage) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(imageDithered == nil)
                    }
                }
                .sheet(isPresented: $isPickerPresented) {
                    return ImagePicker(image: $image, isPresented: $isPickerPresented, sourceType: .photoLibrary)
                }
                
                progressView
            }
        }
    }
    
    private var progressView: some View {
        if isDithering {
            let background: Color
            if colorScheme == .dark {
                background = Color.black.opacity(0.3)
            } else {
                background = Color.white.opacity(0.3)
            }
            
            let view = ZStack {
                ProgressView()
                    .scaleEffect(3, anchor: .center)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .background(background)
            
            return AnyView(view)
        } else {
            let view = EmptyView()
            
            return AnyView(view)
        }
    }
    
    private var imageView: some View {
        if let image = getFramedImage() {
            let view = Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            return AnyView(view)
        } else if let image = self.image {
            let view = Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            return AnyView(view)
        } else {
            let view = EmptyView()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            return AnyView(view)
        }
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
        
        isDithering = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.imageDithered = originalImage.dithered
            
            isDithering = false
            isDitheringAvailable = false
        }
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
    
    private func log(_ logging: () -> String) -> EmptyView {
        NSLog(logging())
        
        return EmptyView()
    }
}
