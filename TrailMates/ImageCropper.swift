struct ImageCropper: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    // Image container with circular mask
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .clipShape(Circle())
                    }
                    .frame(width: geometry.size.width - 40, height: geometry.size.width - 40)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 20) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Button(action: {
                            // Perform the cropping
                            cropImage(geometry: geometry)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Choose")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color("pumpkin"))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    private func cropImage(geometry: GeometryProxy) {
        let renderer = ImageRenderer(content: 
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .clipShape(Circle())
                .frame(width: geometry.size.width - 40, height: geometry.size.width - 40)
        )
        
        if let uiImage = renderer.uiImage {
            croppedImage = uiImage
        }
    }
}