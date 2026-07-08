# 📦 Smart Drop Locker App

A smart and secure locker management mobile application developed using **Flutter** and **IoT technology** to provide an efficient solution for automated package delivery and collection.

The Smart Drop Locker system enables users to securely receive and manage deliveries through an intelligent locker system connected with IoT-enabled hardware. The mobile application acts as the user interface, allowing real-time interaction, notifications, tracking, and management of locker operations.

---

## 🌟 Overview

The Smart Drop Locker App is designed to improve the convenience and security of modern delivery systems by reducing dependency on direct person-to-person package handovers.

Through IoT integration, the system allows users to:

- 📦 Receive packages securely through smart lockers
- 🔔 Get real-time delivery notifications
- 🔐 Access lockers through secure authentication mechanisms
- 📍 Monitor delivery status and locker availability
- ⭐ Provide feedback and rate delivery experiences

---

## ✨ Key Features

### 📱 Mobile Application
- User-friendly Flutter-based mobile interface
- Secure user authentication
- Package delivery tracking
- Real-time notifications
- Delivery history management
- User feedback and rating system

### 🔒 Smart Locker System
- IoT-enabled locker control
- Automated locker access management
- Secure package storage
- Real-time locker status monitoring

### 📡 IoT Integration
- Communication between mobile application and hardware devices
- Sensor-based monitoring
- Remote locker management
- Real-time data synchronization

---

## 🛠️ Technologies Used

### Mobile Development
- **Flutter**
- **Dart**

### IoT & Hardware
- **ESP32 / ESP8266 Microcontroller**
- Sensors and electronic locking mechanisms
- Embedded system communication

### Backend & Database
- Firebase Realtime Database / Firestore
- Cloud-based data synchronization

### Development Tools
- Android Studio
- VS Code
- Arduino IDE
- Git & GitHub

---

## 🏗️ System Architecture

```
User
 │
 │ Mobile Application
 │ (Flutter)
 │
 ▼
Cloud Database
(Firebase)
 │
 │ Real-time Communication
 │
 ▼
IoT Controller
(ESP32/ESP8266)
 │
 ▼
Smart Locker Hardware
(Sensors + Locking System)
```

---

## 📂 Project Structure

```
Smart-Drop-Locker-App/
│
├── lib/
│   ├── main.dart
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   ├── services/
│   └── utils/
│
├── assets/
│
├── pubspec.yaml
│
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

Make sure you have installed:

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- Firebase Configuration
- Android Emulator or Physical Device

Check Flutter setup:

```bash
flutter doctor
```

---

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
```

2. Navigate to the project folder:

```bash
cd Smart-Drop-Locker-App
```

3. Install dependencies:

```bash
flutter pub get
```

4. Configure Firebase:

- Add Firebase configuration files
- Enable required Firebase services
- Update project settings

5. Run the application:

```bash
flutter run
```

---

## 📡 IoT Setup

The hardware component communicates with the application through the connected backend system.

Basic workflow:

1. Delivery person places the package inside the smart locker.
2. IoT controller updates locker status.
3. User receives a notification through the mobile application.
4. User authenticates and unlocks the locker.
5. Package collection status is updated automatically.

---

## 🔮 Future Enhancements

- Face recognition-based authentication
- QR-based locker access
- AI-powered delivery optimization
- Multiple locker station management
- Advanced analytics dashboard
- Smart energy management

---

## 🤝 Contribution

Contributions and suggestions are welcome.

Steps:

1. Fork this repository
2. Create a new branch
3. Commit your changes
4. Submit a pull request

---

## 📄 License

This project is developed for educational and research purposes.

---

## 👩‍💻 Developed By

**Smart Drop Locker Development Team**

[Thurya Nikethani(Thinu)](https://github.com/ThuryaNikethani)
[https://github.com/SanduniKarunathilake](https://github.com/SanduniKarunathilake)
[https://github.com/NimeshKolambage](https://github.com/NimeshKolambage)







---

⭐ If you find this project interesting, consider giving it a star!
