//
//  ContentView.swift
//  diig
//
//  Created by Radovan Paška on 12.02.2021.
//

import SwiftUI

struct ContentView: View {
    
    @State private var isShowPhotoLibrary = false
    @State private var image = UIImage()
    
    var body: some View {
        VStack {
            Image(uiImage: self.image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            Button(action: {
                self.isShowPhotoLibrary = true
            }) {
                HStack {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                    Text("Photo library")
                        .font(.headline)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.horizontal)
            }
        }.sheet(isPresented: $isShowPhotoLibrary) {
            ImagePicker(selectedImage: self.$image, sourceType: .photoLibrary)
            
            // Use camera as a source.
            // ImagePicker(selectedImage: self.$image, sourceType: .camera)
        }
    }
}
