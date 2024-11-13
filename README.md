# TrailMates

TrailMates is an iOS application for spontaneous social meetups along the Ann and Roy Butler Trail in Austin, Texas. Whether you're looking for exercise companions or a quick hangout along the trail, TrailMates helps connect you with friends in real-time.


![TrailmatesScreenshots](https://github.com/user-attachments/assets/0442043b-b68b-4e1b-b817-9dd658cc63a6)



## Features

- **Trail Location Sharing**: Automatically updates your friends when you're active on the trail and shares your real-time location with them, limited strictly to trail usage.
- **Do Not Disturb Mode**: Provides full control over your visibility on the trail.
- **Augmented Reality Enhancements**: Leverages Swift for seamless AR integrations, enabling immersive interactions as you navigate the trail.
- **Privacy-Focused**: Location sharing is trail-specific, with additional privacy settings to ensure users control their visibility.


## Technical Overview

TrailMates started in **React Native**, providing a flexible cross-platform foundation but later transitioned to **Swift** to optimize performance, especially for native iOS AR integrations. Leveraging Swift’s robust performance and ARKit integration, TrailMates achieves fluid, low-latency AR interactions that enhance user experience along the trail.

### Core Libraries and Technologies

- **Swift**: Powers the iOS app, ensuring smooth AR and real-time location updates.
- **ARKit**: Adds augmented reality overlays, giving users spatial awareness and enriching their experience on the trail.
- **CoreLocation**: Manages real-time trail-specific location sharing, with careful handling of background updates to balance accuracy and battery efficiency.
- **Cloud Firestore** (optional): Supports real-time location storage and friend notifications, enabling instant, secure data updates for group interactions.

## Installation and Setup

1. Clone the repository: `git clone https://github.com/username/trailmates.git`
2. Navigate to the project directory: `cd trailmates`
3. Install dependencies: `pod install`
4. Open the `.xcworkspace` file in Xcode: `open TrailMates.xcworkspace`
5. Configure API keys: Set up environment keys for Firestore or other services in your Xcode project.
6. Run the app: `Command + R`

## Future Roadmap

1. **Expanded AR Features**: Plan to add AR gamification elements like friend proximity indicators and interactive checkpoints along the trail.
2. **Custom Privacy Settings**: User-defined location sharing schedules for even more personalized privacy.
3. **Trail Events**: Notifications about public or friend-hosted events along the trail.

## Contribution

Contributions to TrailMates are welcome. To contribute:

1. Fork the repository.
2. Create a new branch.
3. Submit a pull request with clear descriptions and concise commits.

## License

TrailMates is licensed under the MIT License.
