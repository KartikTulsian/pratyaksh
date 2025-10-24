# 📱 Pratyaksh - No Touch, No Cards, Just You

**A smart, automated attendance management system powered by facial recognition and GPS geofencing.**

Pratyaksh revolutionizes traditional attendance tracking by eliminating manual processes and introducing touchless, AI-powered verification. Built for modern educational institutions, it ensures accuracy, transparency, and efficiency in attendance management.

## 🌟 Overview

Pratyaksh addresses critical gaps in current attendance management systems:
- **Time-Consuming Processes**: Automating manual roll calls and data entry
- **Proxy Attendance**: Virtually eliminating fraudulent attendance through biometric verification
- **Data Management**: Handling large volumes of attendance data efficiently
- **Lack of Verification**: Smart validation using AI and location services
- **Transparency Issues**: Real-time sync and accessible attendance records

## ✨ Key Features

### 🤖 AI-Powered Face Recognition
- **Touchless Verification**: No physical contact required for attendance
- **Advanced Detection**: Google ML Kit Face Detection + TensorFlow Lite
- **Face Embeddings**: Secure storage and matching of facial data
- **Adaptive Learning**: Continuous dataset updates for improved accuracy
- **Lighting Adaptability**: Works in various lighting conditions with proper guidance

### 📍 GPS Geofencing
- **Location Verification**: Ensures students are physically present on campus
- **Geofence Zones**: Dynamic boundary creation for different campus areas
- **Mock Location Detection**: Advanced GPS spoofing prevention
- **Wi-Fi/Bluetooth Validation**: Multi-layer location verification
- **Restricted Check-in**: Attendance marking only within authorized zones

### ⏱️ Real-Time Synchronization
- **Instant Updates**: Attendance reflected immediately across all devices
- **Cloud Integration**: Firebase Firestore for seamless data sync
- **Offline Support**: Local data capture with auto-sync when connected
- **Conflict Resolution**: Smart handling of network interruptions

### 👥 Multi-Role Access
- **Students**: Mark attendance, view records, check schedules
- **Teachers**: Monitor real-time attendance, manual overrides, generate reports
- **Administrators**: Manage users, timetables, system configuration

### 📊 Smart Analytics & Reporting
- **Digital Reports**: Automated PDF generation with comprehensive data
- **Visual Dashboards**: Interactive charts and graphs for attendance trends
- **Data Export**: CSV/Excel export for external analysis
- **Custom Filters**: Advanced filtering by date, subject, department

### 🗓️ Dynamic Timetable Management
- **Flexible Scheduling**: Support for changing timetables and special classes
- **Period Activation**: Automatic period detection based on time
- **Conflict Detection**: Alerts for timetable mismatches
- **Multi-Department Support**: Scalable for complex institutional structures

## 🎯 Mission & Impact

Pratyaksh contributes to **UN Sustainable Development Goals**:

- **SDG 4 - Quality Education**: Promoting efficient learning time management
- **SDG 9 - Industry, Innovation & Infrastructure**: Building smart institutional infrastructure
- **SDG 16 - Peace, Justice & Strong Institutions**: Ensuring transparent and accountable systems

## 🛠️ Tech Stack

### Frontend Framework
- **Framework**: Flutter SDK
- **Language**: Dart
- **IDE**: Android Studio / VS Code
- **UI Libraries**: Material Design Components
- **Typography**: Custom brand styling
- **Icons**: Scalable vector iconography

### State Management
- **Architecture**: Provider / Bloc pattern
- **Persistence**: SharedPreferences for local storage
- **Communication**: EventBus for component messaging
- **Data Flow**: Reactive state management

### Backend & Database
- **Backend as a Service**: Firebase
- **Database**: Cloud Firestore
    - Users collection (all roles)
    - Timetable (daily period data)
    - Attendance (logs with GPS & face data)
    - Active Days (admin controls)
- **Authentication**: Firebase Authentication
- **Storage**: Firebase Storage for face embeddings

### AI & Machine Learning
- **Face Detection**: Google ML Kit Face Detection
- **Face Recognition**: TensorFlow Lite models
- **Model Training**: Custom face embedding algorithms
- **Data Processing**: On-device ML for privacy

### Location Services
- **GPS Tracking**: geolocator package
- **Geofencing**: geofence_service
- **Location Validation**: Mock location detection
- **Multi-layer Verification**: GPS + Wi-Fi + Bluetooth

### Data Visualization & Reports
- **Charts**: Interactive data visualization libraries
- **PDF Generation**: Digital report creation
- **Data Export**: CSV/Excel generation
- **Analytics**: Custom filtering and sorting toolkit

### Testing & Deployment
- **Development**: Flutter Debug & Profile Modes
- **Testing**: Widget, Integration, and Unit tests
- **Deployment**: Android APK Release
- **Monitoring**: Firebase Console for analytics and crash reporting

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- Android Studio / VS Code with Flutter plugin
- Firebase account
- Android device/emulator (API level 21+)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/your-username/pratyaksh.git
cd pratyaksh
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Firebase Setup**

Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)

Download `google-services.json` and place it in:
```
android/app/google-services.json
```

4. **Configure Firebase Services**

Enable the following in Firebase Console:
- Authentication (Email/Password, Google Sign-In)
- Cloud Firestore
- Firebase Storage
- Firebase Analytics

5. **Set up environment variables**

Create a `.env` file in the root directory:
```env
# Firebase Configuration
FIREBASE_API_KEY=your_api_key
FIREBASE_APP_ID=your_app_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_storage_bucket

# ML Models
FACE_DETECTION_MODEL=path_to_model
FACE_RECOGNITION_THRESHOLD=0.85

# Geofencing
GEOFENCE_RADIUS=100
LOCATION_UPDATE_INTERVAL=5000
```

6. **Download ML Models**

Place TensorFlow Lite models in:
```
assets/models/
├── face_detection.tflite
└── face_recognition.tflite
```

7. **Run the app**
```bash
# Debug mode
flutter run

# Release mode
flutter run --release

# Specific device
flutter run -d <device_id>
```

## 📁 Project Structure
```
pratyaksh/
├── lib/
│   ├── spalsh_screen.dart        # App entry point
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── app_user_model.dart
│   │   ├── attendance_model.dart
│   │   ├── subject_model.dart
│   │   ├── teacher_model.dart
│   │   └── student_model.dart
│   ├── screens/                  # UI screens
│   │   ├── auth/                # Authentication screens
│   │   ├── student/             # Student dashboard
│   │   ├── teacher/             # Teacher dashboard
│   │   └── admin/               # Admin dashboard
│   ├── widgets/                  # Reusable widgets
│   │   ├── attendance_card.dart
│   │   ├── face_capture.dart
│   │   ├── location_widget.dart
│   │   ├── create_period.dart
│   │   ├── create_student.dart
│   │   ├── create_teacher.dart
│   │   ├── day_selector.dart
│   │   ├── face_attendance_screen.dart
│   │   ├── face_registration.dart
│   │   ├── subject_card.dart
│   │   ├── update_password.dart
│   │   ├── update_period.dart
│   │   ├── update_student.dart
│   │   └── update_teacher.dart
│   ├── services/                 # Business logic
│   │   ├── auth_service.dart
│   │   ├── attendance_service.dart
│   │   ├── database_service.dart
│   │   ├── embedding_manager_service.dart
│   │   ├── face_embedding_service.dart
│   │   ├── face_recognition_service.dart
│   │   └── firestore_service.dart
├── assets/
│   ├── models/                   # ML models
│   └── google_fonts/
├── android/                      # Android-specific files
├── ios/                          # iOS-specific files (future)
├── test/                         # Unit & widget tests
└── pubspec.yaml                  # Dependencies
```

## 🔧 Available Commands
```bash
# Run in debug mode
flutter run

# Run in profile mode (performance testing)
flutter run --profile

# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage

# Analyze code
flutter analyze

# Format code
flutter format .

# Clean build files
flutter clean

# Check device/emulator list
flutter devices

# Generate icons
flutter pub run flutter_launcher_icons:main

# Check outdated packages
flutter pub outdated
```

## 🧪 Testing

### Run Unit Tests
```bash
flutter test test/unit/
```

### Run Widget Tests
```bash
flutter test test/widget/
```

### Run Integration Tests
```bash
flutter test test/integration/
```

### Generate Coverage Report
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 📱 Features by User Role

### 👨‍🎓 Student Features
- Face-based attendance marking
- View personal attendance records
- Access timetable and schedule
- Receive attendance notifications
- View attendance percentage
- Download attendance reports

### 👨‍🏫 Teacher Features
- Monitor real-time class attendance
- Manual attendance override capability
- Generate class-wise reports
- View student attendance history
- Activate/deactivate attendance periods
- Export attendance data

### 👨‍💼 Admin Features
- Manage users (students, teachers)
- Configure timetables
- Set up geofence boundaries
- System-wide analytics
- Control active attendance days
- Manage department settings
- Bulk operations support

## 🛡️ Security & Privacy

### Data Protection
- **Face Embeddings**: Encrypted storage in Firebase
- **Secure Communication**: HTTPS for all API calls
- **Access Control**: Role-based permissions
- **Data Minimization**: Only essential data collected
- **GDPR Compliance**: User data deletion capabilities

### Privacy Measures
- Face data stored as mathematical embeddings, not images
- Location data used only during attendance window
- No tracking outside designated areas
- Transparent data usage policies
- User consent for biometric data

## 🔧 Risk Mitigation

### Face Recognition Challenges
- **Solution**: Advanced ML models with user positioning guidance
- **Fallback**: Manual override by teacher
- **Continuous Improvement**: Regular dataset updates

### GPS Spoofing
- **Solution**: Mock location detection
- **Multi-layer Verification**: Wi-Fi + Bluetooth validation
- **Restricted Zones**: Geofenced attendance areas

### Battery Optimization
- **Solution**: Low-power ML models
- **Limited Usage**: Location tracking only during attendance window
- **User Guidance**: Power consumption tips

### Offline Functionality
- **Solution**: Local data capture with auto-sync
- **Cached Timetable**: Offline access to schedules
- **Queue System**: Pending uploads when online

### Device Compatibility
- **Solution**: Adaptive ML models for different devices
- **Minimum Requirements**: API level 21+ (Android 5.0+)
- **Fallback Options**: Teacher-approved manual attendance

## 🎨 UI/UX Features

- **Material Design**: Modern, intuitive interface
- **Brand Styling**: Custom typography and color schemes
- **Adaptive Layouts**: Responsive design for various screen sizes
- **Dark Mode**: Eye-friendly viewing in low light
- **Accessibility**: Screen reader support and high contrast modes
- **Smooth Animations**: Fluid transitions and micro-interactions

## 📊 Performance Optimization

- **Lazy Loading**: Efficient data fetching
- **Image Optimization**: Compressed face data storage
- **Caching Strategy**: Local storage for frequent data
- **Background Processing**: Non-blocking operations
- **Memory Management**: Efficient resource utilization

## 🔄 Development Workflow

### Project Timeline
- ✅ Feasibility Study & SRS (18 Jul - 01 Aug 2025)
- 🔄 Design Documents (25 Jul - 08 Aug 2025)
- 🔄 Development Phase (25 Jul - 22 Aug 2025)
- ⏳ Implementation (08 Aug - 15 Aug 2025)
- ⏳ Testing & Debugging (15 Aug - 22 Aug 2025)
- ⏳ Quality Management (22 Aug - 29 Aug 2025)
- ⏳ Deployment (29 Aug - 12 Sep 2025)

## 🌐 Future Enhancements

- 📱 iOS app development
- 🌐 Web dashboard for administrators
- 🔔 Push notifications for attendance alerts
- 📊 Advanced analytics with AI insights
- 🗣️ Voice-based attendance commands
- 🌍 Multi-language support
- 🎓 Integration with Learning Management Systems
- 📧 Email reports for parents
- 🔗 API for third-party integrations

## 👥 Team

**Developed by IEM Software Engineering Lab (PCCCS594)**

- **Debayan De** (12023052004004) - Team Lead & Backend Developer
- **Debosmita Ghosh** (12023052004035) - Full Stack Support & Documentation Lead
- **Kartik Tulsian** (12023052004036) - Solution Architect & UI/UX Designer

**Mentored by:**
- Prof. Subhabrata Sengupta
- Prof. Dr. Rupayan Das

**Institution:** Department of Information Technology, Institute of Engineering and Management

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure your code follows Flutter style guidelines and includes tests.

## 📄 License

This project is part of an academic curriculum at IEM and is subject to institutional guidelines. For commercial use or licensing inquiries, please contact the team.

## 📞 Support & Contact

- 📧 Email: []

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Google ML Kit for face detection
- TensorFlow for machine learning capabilities
- All contributors and testers
- IEM faculty for guidance and support

## 📚 Learn More

To learn more about the technologies used:

- [Flutter Documentation](https://docs.flutter.dev/) - Flutter features and widgets
- [Firebase Documentation](https://firebase.google.com/docs) - Backend services
- [ML Kit Documentation](https://developers.google.com/ml-kit) - Face detection
- [TensorFlow Lite](https://www.tensorflow.org/lite) - On-device ML
- [Dart Language](https://dart.dev/guides) - Programming language

## 🔗 Quick Links

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter Widget Catalog](https://docs.flutter.dev/development/ui/widgets)
- [Flutter YouTube Channel](https://www.youtube.com/c/flutterdev)

**Made with 💙 for modern educational institutions**

*No Touch, No Cards, Just You - Redefining attendance management with AI and innovation.*