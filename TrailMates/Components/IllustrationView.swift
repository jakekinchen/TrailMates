struct IllustrationView: View {
    var body: some View {
        ZStack {
            // Left group of birds
            Group {
                Bird(index: 0, position: .leftGroup)
                Bird(index: 1, position: .leftGroup)
                Bird(index: 2, position: .leftGroup)
            }
            
            // Right group of birds
            Group {
                Bird(index: 3, position: .rightGroup)
                Bird(index: 4, position: .rightGroup)
            }
            
            // Solo bird
            Bird(index: 5, position: .solo)
        }
    }
}

enum BirdPosition {
    case leftGroup
    case rightGroup
    case solo
    
    var basePosition: CGPoint {
        switch self {
        case .leftGroup:
            return CGPoint(x: -120, y: -20)
        case .rightGroup:
            return CGPoint(x: 80, y: -60)
        case .solo:
            return CGPoint(x: 40, y: -100)
        }
    }
}

struct Bird: View {
    let index: Int
    let position: BirdPosition
    
    // Animation states
    @State private var xOffset: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    // Create random but consistent values for each bird
    private let scale: CGFloat
    private let horizontalFlip: Bool
    private let animationDelay: Double
    private let animationDuration: Double
    private let pathAmplitude: CGFloat
    private let pathFrequency: Double
    
    init(index: Int, position: BirdPosition) {
        self.index = index
        self.position = position
        
        // Use the index to create deterministic but seemingly random values
        let seed = Double(index) * 13.7
        self.scale = CGFloat(cos(seed) * 0.2 + 1.0) // Scale between 0.8 and 1.2
        self.horizontalFlip = sin(seed * 2) > 0
        self.animationDelay = Double(index) * 0.5
        self.animationDuration = Double(cos(seed) * 1.5 + 4.5) // Duration between 3 and 6 seconds
        self.pathAmplitude = CGFloat(sin(seed) * 15 + 20) // Amplitude between 5 and 35
        self.pathFrequency = Double(cos(seed * 2) * 0.5 + 1.0) // Frequency between 0.5 and 1.5
    }
    
    var body: some View {
        Image(systemName: "bird.fill")
            .foregroundColor(.black)
            .scaleEffect(x: horizontalFlip ? -scale : scale, y: scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: position.basePosition.x + xOffset + getGroupOffset().x,
                   y: position.basePosition.y + yOffset + getGroupOffset().y)
            .onAppear {
                startAnimations()
            }
    }
    
    private func getGroupOffset() -> CGPoint {
        // Add slight offset within groups
        switch position {
        case .leftGroup:
            return CGPoint(x: CGFloat(index % 3) * 30,
                         y: CGFloat(index % 3) * 15)
        case .rightGroup:
            return CGPoint(x: CGFloat(index % 2) * 40,
                         y: CGFloat(index % 2) * -20)
        case .solo:
            return .zero
        }
    }
    
    private func startAnimations() {
        // Delay the start of animations for each bird
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
            // Flight path animation
            withAnimation(
                Animation
                    .easeInOut(duration: animationDuration)
                    .repeatForever(autoreverses: true)
            ) {
                xOffset = pathAmplitude * 2
                yOffset = -pathAmplitude
            }
            
            // Independent rotation animation
            withAnimation(
                Animation
                    .easeInOut(duration: animationDuration * 0.7)
                    .repeatForever(autoreverses: true)
            ) {
                rotation = horizontalFlip ? -15 : 15
            }
            
            // Add subtle figure-eight movement
            let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                let t = Date().timeIntervalSince1970 * pathFrequency
                let additionalX = sin(t) * Double(pathAmplitude) * 0.3
                let additionalY = cos(t * 2) * Double(pathAmplitude) * 0.2
                
                withAnimation(.linear(duration: 0.02)) {
                    xOffset = pathAmplitude + CGFloat(additionalX)
                    yOffset = -pathAmplitude + CGFloat(additionalY)
                }
            }
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

