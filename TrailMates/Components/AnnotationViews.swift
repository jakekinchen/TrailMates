//
//  FriendAnnotationView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//


// MARK: - AnnotationViews.swift
import UIKit
import MapKit

// MARK: - Friend Annotation View
final class FriendAnnotationView: MKAnnotationView {
    private let imageView = UIImageView()
    private let radarView = RadarPulseView()
    private let isMock: Bool
    
    init(annotation: MKAnnotation?, reuseIdentifier: String?, isMock: Bool = false) {
        self.isMock = isMock
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.isMock = false
        super.init(coder: aDecoder)
        setupViews()
    }
    
    private func setupViews() {
        frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        centerOffset = CGPoint(x: 0, y: -25)
        
        // Configure image view
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 25
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = isMock ?
            UIColor.systemGray.cgColor : UIColor.white.cgColor
        addSubview(imageView)
        
        // Configure radar view
        radarView.frame = CGRect(x: -25, y: -25, width: 100, height: 100)
        insertSubview(radarView, belowSubview: imageView)
    }
    
    func configure(with friend: User) {
        if let imageData = friend.profileImageData,
           let image = UIImage(data: imageData) {
            imageView.image = image
        } else {
            imageView.image = UIImage(named: "defaultProfilePic")
        }
        
        if friend.isActive {
            radarView.startAnimating()
        } else {
            radarView.stopAnimating()
        }
        
        if isMock {
            imageView.alpha = 0.7
            radarView.alpha = 0.7
        }
    }
}

// MARK: - Event Annotation View
final class EventAnnotationView: MKAnnotationView {
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }
    
    private func setupViews() {
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        centerOffset = CGPoint(x: 0, y: -20)
        
        containerView.frame = bounds
        containerView.backgroundColor = UIColor(named: "pine")
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        addSubview(containerView)
        
        iconImageView.frame = bounds.insetBy(dx: 10, dy: 10)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.image = UIImage(systemName: "calendar")
        containerView.addSubview(iconImageView)
        
        canShowCallout = true
    }
    
    func configure(with event: Event) {
        // Additional configuration based on event type or status
    }
}

// MARK: - Recommended Location View
final class RecommendedLocationView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        markerTintColor = UIColor(named: "pine")
        glyphImage = UIImage(systemName: "star.fill")
        canShowCallout = true
        
        // Add right callout accessory view if needed
        let button = UIButton(type: .detailDisclosure)
        rightCalloutAccessoryView = button
    }
}

// MARK: - Radar Pulse View
final class RadarPulseView: UIView {
    private var pulseLayer: CAShapeLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPulseLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPulseLayer()
    }
    
    private func setupPulseLayer() {
        let circle = CAShapeLayer()
        circle.path = UIBezierPath(circleIn: bounds).cgPath
        circle.fillColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        circle.opacity = 0
        
        pulseLayer = circle
        layer.addSublayer(circle)
    }
    
    func startAnimating() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.5
        pulseAnimation.fromValue = 0.8
        pulseAnimation.toValue = 1.5
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.duration = 1.5
        opacityAnimation.fromValue = 0.6
        opacityAnimation.toValue = 0
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        
        pulseLayer?.add(pulseAnimation, forKey: "pulse")
        pulseLayer?.add(opacityAnimation, forKey: "opacity")
    }
    
    func stopAnimating() {
        pulseLayer?.removeAllAnimations()
    }
}

// MARK: - Helper Extension
extension UIBezierPath {
    convenience init(circleIn rect: CGRect) {
        self.init(ovalIn: rect)
    }
}