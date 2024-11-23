import SwiftUI

struct ImageCropper: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private func calculateFitScale(for diameter: CGFloat) -> CGFloat {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        if aspectRatio > 1 {
            return diameter / imageSize.height
        } else {
            return diameter / imageSize.width
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height) * 0.8
            
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(scale)
                            .offset(x: offset.width, y: offset.height)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            scale = max(1.0, scale * delta)
                                            lastScale = value
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
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
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .frame(width: diameter, height: diameter)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Button(action: {
                            cropImage(diameter: diameter)
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
    
    private func cropImage(diameter: CGFloat) {
        let size = CGSize(width: diameter, height: diameter)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        context.addPath(circlePath.cgPath)
        context.clip()
        
        let fitScale = calculateFitScale(for: diameter)
        let drawScale = scale * fitScale
        
        let scaledSize = CGSize(
            width: image.size.width * drawScale,
            height: image.size.height * drawScale
        )
        
        let drawRect = CGRect(
            x: (size.width - scaledSize.width) / 2 + offset.width,
            y: (size.height - scaledSize.height) / 2 + offset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        image.draw(in: drawRect)
        
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            croppedImage = newImage
        }
    }
}
