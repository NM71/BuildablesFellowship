# 📋 TaskFlow - Collaborative Todo App

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"/>
  <img src="https://img.shields.io/badge/Google%20Maps-4285F4?style=for-the-badge&logo=google-maps&logoColor=white" alt="Google Maps"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=white" alt="Firebase"/>
</p>

A modern collaborative todo application built with Flutter and Supabase, featuring real-time collaboration, location tracking, file attachments, and push notifications.

## ✨ Features

- ✅ **Task Management** - Create, edit, complete, and delete tasks
- ✅ **Real-time Collaboration** - Invite collaborators and work together
- ✅ **Location Tracking** - Share locations with task collaborators on interactive maps
- ✅ **File Attachments** - Upload images and documents to tasks
- ✅ **Push Notifications** - Get notified about task updates
- ✅ **Offline Support** - Works without internet connection
- ✅ **Cross-platform** - Android & iOS support

## 🛠️ Tech Stack

- **Frontend**: Flutter, Dart, Riverpod
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime)
- **Maps**: Google Maps Flutter
- **Notifications**: Firebase Cloud Messaging
- **Location**: Geolocator, Permission Handler

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.8.0+)
- Dart SDK (3.0.0+)
- Android Studio or VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/NM71/BuildablesFellowship.git
   cd BuildablesFellowship/Buildables-Task-1/todo_supabase
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up environment variables**
   Create `.env` file:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_key
   GOOGLE_MAPS_API_KEY=your_maps_key
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Usage

1. **Sign up/Login** with your account
2. **Create tasks** and organize them by categories
3. **Invite collaborators** to work together
4. **Share locations** and track progress on maps
5. **Attach files** to tasks for better context
6. **Get notifications** for all updates

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── providers/                # State management
├── screens/                  # UI screens
├── services/                 # Business logic
├── widgets/                  # Reusable components
└── utils/                    # Helper utilities
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## � License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ using Flutter & Supabase**
