# 📋 TaskFlow - Collaborative Todo App

[![Flutter](https://img.shields.io/badge/Flutter-3.8.0-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0-blue.svg)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-2.9.1-green.svg)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A modern, feature-rich collaborative todo application built with Flutter and Supabase, featuring real-time collaboration, location tracking, file attachments, and push notifications.

## ✨ Features

### 🎯 Core Functionality
- ✅ **Task Management**: Create, read, update, and delete tasks with full CRUD operations
- ✅ **Categories & Organization**: Organize tasks by categories (Work, Personal, Shopping, etc.)
- ✅ **Real-time Sync**: Instant synchronization across all devices using Supabase
- ✅ **Offline Support**: Local SQLite storage for offline functionality

### 👥 Collaboration Features
- ✅ **Multi-user Collaboration**: Invite collaborators to tasks
- ✅ **Real-time Collaboration**: See collaborators' changes instantly
- ✅ **Role-based Access**: Task owners and collaborators with appropriate permissions
- ✅ **Invitation System**: Send and accept task invitations

### 📍 Location & Maps
- ✅ **Location Tracking**: Real-time GPS location sharing for collaborators
- ✅ **Interactive Maps**: Google Maps integration with custom markers
- ✅ **Privacy Controls**: Location sharing only with task collaborators
- ✅ **Accuracy Visualization**: GPS accuracy circles and status indicators

### 📎 File Management
- ✅ **File Attachments**: Upload images and documents to tasks
- ✅ **Supabase Storage**: Secure cloud storage for attachments
- ✅ **Thumbnail Generation**: Automatic image thumbnails
- ✅ **File Type Validation**: Support for various file formats

### 🔔 Notifications
- ✅ **Push Notifications**: Firebase Cloud Messaging integration
- ✅ **Real-time Alerts**: Instant notifications for task updates
- ✅ **Local Notifications**: Scheduled reminders and alerts
- ✅ **Customizable Settings**: Notification preferences

### 🔐 Security & Authentication
- ✅ **Supabase Auth**: Secure user authentication
- ✅ **Row Level Security**: Database-level access control
- ✅ **JWT Tokens**: Secure API communication
- ✅ **Data Encryption**: Encrypted data storage

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **Riverpod** - State management
- **Google Maps Flutter** - Interactive maps
- **Image Picker** - Media selection
- **Cached Network Image** - Image caching

### Backend & Database
- **Supabase** - Backend-as-a-Service
- **PostgreSQL** - Primary database
- **Supabase Storage** - File storage
- **Supabase Realtime** - Real-time subscriptions

### Services & APIs
- **Firebase Cloud Messaging** - Push notifications
- **Google Maps API** - Location services
- **Geolocator** - GPS location tracking
- **Permission Handler** - Device permissions

### Development Tools
- **Flutter SDK** - Mobile development
- **Android Studio / VS Code** - IDE
- **Git** - Version control
- **FlutterFire CLI** - Firebase integration

## 📋 Prerequisites

Before running this application, make sure you have the following installed:

- **Flutter SDK** (3.8.0 or higher)
- **Dart SDK** (3.0.0 or higher)
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **Git** (for version control)

### Environment Setup
1. Install Flutter: [Flutter Installation Guide](https://flutter.dev/docs/get-started/install)
2. Verify installation:
   ```bash
   flutter doctor
   ```
3. Set up your IDE:
   - [Android Studio](https://developer.android.com/studio)
   - [Visual Studio Code](https://code.visualstudio.com/) with Flutter extension

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/NM71/BuildablesFellowship.git
cd BuildablesFellowship/Buildables-Task-1/todo_supabase
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Environment Configuration
Create a `.env` file in the root directory:
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### 4. Supabase Setup

#### Create a Supabase Project
1. Go to [Supabase](https://supabase.com/)
2. Create a new project
3. Note your project URL and anon key

#### Database Migration
Run the SQL migration in your Supabase SQL Editor:
```sql
-- Copy the entire content from supabase_location_migration.sql
-- and execute it in Supabase SQL Editor
```

#### Storage Setup
1. Go to **Storage** in your Supabase dashboard
2. Create a bucket named `task-attachments`
3. Set bucket to **Public** for file access
4. Configure RLS policies for secure access

### 5. Google Maps Setup

#### Enable APIs
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS (optional)

#### Create API Key
1. Create credentials → API key
2. Restrict the key to:
   - Maps SDK for Android
   - Add your package name: `com.example.todo_supabase`
   - Add SHA-1 fingerprint from your debug keystore

#### Android Configuration
The API key is already configured in `android/app/src/main/AndroidManifest.xml`

### 6. Firebase Setup (for Notifications)

#### Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Add Android app with package name: `com.example.todo_supabase`
4. Download `google-services.json` and place it in `android/app/`

#### Enable Cloud Messaging
1. Go to **Cloud Messaging** in Firebase Console
2. Generate a server key for push notifications

### 7. Run the Application
```bash
# For Android
flutter run

# For iOS (macOS only)
flutter run --flavor development
```

## 📱 Usage

### Getting Started
1. **Sign Up/Login**: Create an account or sign in
2. **Create Tasks**: Add your first todo item
3. **Organize**: Use categories to organize your tasks
4. **Collaborate**: Invite others to collaborate on tasks

### Key Features Usage

#### Task Management
- **Create**: Tap the "+" button to add new tasks
- **Edit**: Long press on a task to edit details
- **Complete**: Check the checkbox to mark as done
- **Delete**: Swipe left on a task to delete

#### Collaboration
- **Invite Users**: Go to task details → Collaborators → Invite
- **Accept Invitations**: Check pending invitations in Profile
- **Real-time Sync**: See collaborators' changes instantly

#### Location Tracking
- **Enable Location**: Grant location permissions when prompted
- **View Map**: Tap "View Map" in task details to see collaborators
- **Privacy**: Location only shared with task collaborators

#### File Attachments
- **Add Files**: Tap attachment icon in task details
- **Upload**: Select images or documents from gallery/camera
- **View**: Tap on attachments to view or download

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point
├── providers/
│   ├── task_provider.dart       # Task state management
│   └── auth_provider.dart       # Authentication state
├── screens/
│   ├── auth/                    # Authentication screens
│   ├── task_page.dart           # Main task list
│   ├── task_detail_page.dart    # Task details & editing
│   ├── profile_page.dart        # User profile & settings
│   ├── collaborator_map_screen.dart  # Location map view
│   └── pending_invitations_page.dart # Invitation management
├── services/
│   ├── auth_service.dart        # Authentication logic
│   ├── database_service.dart    # Local SQLite operations
│   ├── location_service.dart    # GPS & location tracking
│   ├── file_service.dart        # File upload/download
│   ├── collaboration_service.dart # Multi-user features
│   └── notification_service.dart # Push notifications
├── widgets/
│   ├── auth_wrapper.dart        # Auth state wrapper
│   ├── collaborator_map.dart    # Map widget
│   ├── file_attachment_widget.dart # File picker
│   ├── file_thumbnail.dart      # File preview
│   └── invite_user_dialog.dart  # User invitation
└── utils/
    └── custom_appbar.dart       # Custom app bar component
```

## 🔧 Configuration Files

- `pubspec.yaml` - Flutter dependencies and app configuration
- `android/app/build.gradle` - Android-specific configuration
- `android/app/src/main/AndroidManifest.xml` - Android permissions
- `ios/Runner/Info.plist` - iOS configuration
- `supabase_location_migration.sql` - Database schema
- `.env` - Environment variables (create this file)

## 🧪 Testing

### Running Tests
```bash
flutter test
```

### Integration Testing
```bash
flutter drive --target=test_driver/app.dart
```

### Code Analysis
```bash
flutter analyze
```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Development Guidelines
- Follow Flutter's [style guide](https://flutter.dev/docs/development/tools/formatting)
- Write clear, concise commit messages
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting PR

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Beautiful native apps in record time
- [Supabase](https://supabase.com/) - The open source Firebase alternative
- [Google Maps](https://developers.google.com/maps) - Powerful mapping platform
- [Firebase](https://firebase.google.com/) - App development platform

## 📞 Support

If you have any questions or need help:

- 📧 **Email**: [your-email@example.com]
- 💬 **Issues**: [GitHub Issues](https://github.com/NM71/BuildablesFellowship/issues)
- 📖 **Documentation**: [Wiki](https://github.com/NM71/BuildablesFellowship/wiki)

---

**Made with ❤️ using Flutter & Supabase**
