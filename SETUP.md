# Setup and Run Guide - SmartBoard Go

This document outlines the step-by-step instructions for running the SmartBoard Go FastAPI backend and the Flutter cross-platform client app.

---

## Prerequisites

Ensure you have the following installed on your machine:
- **Flutter SDK** (3.x recommended)
- **Dart SDK** (installed automatically with Flutter)
- **Docker Desktop** (for running PostgreSQL and Redis)
- **Python 3.10+** (if running backend without Docker)

---

## Part 1: Run the Backend Services

The easiest way to start PostgreSQL, Redis, and the FastAPI application is via Docker Compose.

### Method A: Docker Compose (Recommended)
1. Open a terminal and navigate to the `backend/` directory:
   ```bash
   cd backend
   ```
2. Build and start all containers in detached mode:
   ```bash
   docker compose up --build -d
   ```
3. The FastAPI app will now be running at `http://localhost:8000`. You can access the Interactive Swagger documentation at `http://localhost:8000/docs`.

### Method B: Manual Standalone Running
If you do not have Docker installed, you can spin up PostgreSQL and Redis manually, then run:
1. Navigate to the `backend/` directory:
   ```bash
   cd backend
   ```
2. Create and activate a python virtual environment:
   ```bash
   python -m venv venv
   # On Windows:
   venv\Scripts\activate
   # On Mac/Linux:
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Set environment configurations (Optional. Defaults will run on localhost):
   ```bash
   set POSTGRES_HOST=localhost
   set REDIS_HOST=localhost
   ```
5. Run the FastAPI development server:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

---

## Part 2: Run the Flutter Frontend Application

Before running the Flutter client, ensure you have fetched the required package dependencies.

1. Navigate to the project root directory (`edu_board`):
   ```bash
   cd edu_board
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

### 1. Running on Flutter Web (Laptop Whiteboard Viewer)
To open the whiteboard host screen where the QR Code is generated:
```bash
flutter run -d chrome
```

### 2. Running on Android Emulator / Physical Device (Mobile Writing Pad)
For the mobile writing controller (transforms phone into drawing pad):
```bash
flutter run -d <android-device-id>
```
*Note: The Flutter client is configured to connect to `10.0.2.2:8000` (which is the Android Emulator's loopback route to your computer's localhost). If deploying on a physical Android phone, make sure to change the host IP in `lib/core/constants.dart` to your computer's local Wi-Fi IP address (e.g. `192.168.x.x`).*

### 3. Running on iOS Simulator / macOS
Ensure CocoaPods is installed and run:
```bash
cd ios
pod install
cd ..
flutter run -d iphone
```

### 4. Running on Windows Desktop Client
To run as a native Windows desktop client:
```bash
flutter run -d windows
```

---

## Part 3: Testing Real-time Sync

To verify that the pairing and real-time canvas updates are operating:
1. Run the app in **Web Mode** (acting as the whiteboard host).
2. Go to **Host Screen** tab -> Click **Generate Session Code** -> You will see a 6-digit code and a QR code (e.g. `ABCXYZ`).
3. Run the app on **Android/iOS** (acting as the writing pad controller).
4. Go to **Pair Writing Pad** tab -> Scan the Web QR code using your phone camera (or input `ABCXYZ` manually in the Join input on the dashboard).
5. The Web screen will automatically detect the connection and open the blank whiteboard.
6. Choose the **Pen** or **Highlighter** tool on your phone and sketch. You will see the calligraphic strokes and geometric shapes appear instantly on the laptop web browser!
