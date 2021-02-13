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
    
    @State private var image: UIImage? = nil
    @State private var imageDithered: UIImage? = nil
    @State private var frameColor: UIColor? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                imageView
                Spacer()
            }
            .navigationBarTitle(Text("diig"), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.primaryAction) {
                    Button(action: { isPickerPresented = true }) {
                        Image(systemName: "plus.app.fill")
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: ditherImage) {
                        Image(systemName: "wand.and.rays")
                    }
                    .disabled(image == nil)
                    
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            self.frameColor = nil
                        }) {
                            Image(systemName: "square.slash")
                        }
                        .frame(minWidth: 0, maxWidth: 48, minHeight: 0)
                        .disabled(imageDithered == nil)
                        
                        Divider()
                        
                        Button(action: {
                            self.frameColor = .white
                        }) {
                            Image(systemName: "square.fill")
                        }
                        .disabled(imageDithered == nil)
                        
                        Divider()
                        
                        Button(action: {
                            self.frameColor = .black
                        }) {
                            Image(systemName: "square")
                        }
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
                ImagePicker(image: $image, isPresented: $isPickerPresented, sourceType: .photoLibrary)
            }
        }
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
