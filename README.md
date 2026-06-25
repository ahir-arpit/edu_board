# SmartBoard Go (Edu Board)

SmartBoard Go is a premium, cross-platform educational ecosystem that transforms a mobile device (smartphone or tablet) into a digital writing pad and synchronized controller, while turning a laptop/web application into a smart interactive whiteboard viewer.

As a teacher writes or draws on their phone using a stylus or finger, the contents render in real-time on the paired laptop screen via low-latency WebSocket communication.

---

## Architectural Features

1. **Dual Pairing Handshake**: Host displays a QR code and a 6-digit session pin; the phone client scans the QR code or inputs the pin to establish instant synchronization.
2. **Infinite Canvas**: Interactive whiteboard featuring multi-finger pan & zoom, single-finger calligraphy sketch, and graph paper grid background.
3. **Geometry Toolkit**: Draw lines, arrows, rectangles, circles, and triangles with real-time vector sharing.
4. **Vector Serialization**: Freehand shapes are converted to coordinate data arrays and pressure vectors, allowing infinite scaling on the host whiteboard without pixelation.
5. **Calligraphy Rendering**: Utilizes the `perfect_freehand` algorithm to draw smooth pressure-sensitive calligraphy ink paths.
6. **Multi-Page Layouts**: Organize whiteboard workspace pages, navigate backward/forward, and clear elements with full remote synchronization.
7. **Vector Document Exports**: Export drawing paths into native vector PDF documents or capture high-resolution screenshots for system sharing.

---

## Technology Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.x (Web, Android, iOS, Desktop)
- **State Management**: Riverpod (for structured reactive states)
- **Routing**: GoRouter (declarative routing for cross-platform layouts)
- **Themes**: Material 3 (with custom light, dark, and glassmorphic decoration systems)
- **Canvas Rendering**: CustomPainter integrated with `perfect_freehand`
- **Scanning & Pairing**: `mobile_scanner` and `qr_flutter`

### Backend (FastAPI)
- **Framework**: FastAPI
- **WebSockets**: Native ASGI WebSockets for low-latency synchronization
- **Database**: PostgreSQL (managed via SQLAlchemy)
- **In-Memory Cache**: Redis (for active session pub/sub and buffer storage)
- **PDF Vector Engine**: ReportLab (renders matching vector shapes on the server side)

---

## Folder Structure

### Flutter Frontend (`lib/`)
```
lib/
├── core/
│   ├── constants.dart      # API, WebSocket hosts and preferences keys
│   ├── router.dart         # GoRouter path definitions
│   └── theme.dart          # Light/Dark styles, glassmorphic modifiers
├── models/
│   ├── board.dart          # Whiteboard metadata model
│   ├── drawing_point.dart  # x, y, pressure touch data
│   ├── geometry_shape.dart # Vector shape definition (line, arrow, rect, etc.)
│   ├── session.dart        # QR room connection session details
│   └── stroke.dart         # Calligraphy stroke containing drawing points
├── services/
│   ├── auth_service.dart   # Firebase Auth + Google Sign-In with local developer mocks
│   ├── board_service.dart  # REST client for whiteboard CRUD and pairing
│   ├── export_service.dart # Handles local PDF rendering, sharing and printing
│   └── websocket_service.dart # Real-time duplex sync connection manager
├── features/
│   ├── auth/               # Splash, Login, Register, Forgot Password screens
│   ├── dashboard/          # Whiteboard CRUD manager and connection options
│   ├── pairing/            # QR code generator and Mobile Scanner tab views
│   ├── whiteboard/         # Custom painter canvas, toolbars, and geometry tools
│   └── settings/           # Theme adjustments and notification setups
├── app.dart                # App MaterialApp config
└── main.dart               # App entry point initializing Firebase
```

### FastAPI Backend (`backend/`)
```
backend/
├── app/
│   ├── api/
│   │   ├── auth.py         # Registration and JWT login endpoints
│   │   ├── boards.py       # Whiteboard CRUD
│   │   ├── exports.py      # PDF rendering API using ReportLab
│   │   └── sessions.py     # Pair handshakes and room code creation
│   ├── core/
│   │   ├── config.py       # Pydantic configuration variables
│   │   └── database.py     # SQLAlchemy DB connection setup
│   ├── models/
│   │   └── models.py       # SQLAlchemy tables definitions
│   ├── schemas/
│   │   └── schemas.py      # Pydantic validation schemas
│   ├── services/
│   │   └── websocket_manager.py # WebSocket room mapping and Redis pub/sub
│   └── main.py             # FastAPI entrypoint, websocket loop
├── requirements.txt        # Server dependencies
├── Dockerfile              # Docker image configuration
└── docker-compose.yml      # Orchestrates PostgreSQL, Redis, and FastAPI app
```

---

## WebSocket Messaging API

Real-time canvas updates are routed using standard JSON messages over WebSocket channels:

### 1. `draw_stroke`
Client draws a freehand calligraphy line.
```json
{
  "event": "draw_stroke",
  "session_code": "PIN123",
  "data": {
    "stroke_id": "uuid-string",
    "tool": "pen",
    "color": "0xFF2196F3",
    "width": 4.0,
    "points": [
      {"x": 100.0, "y": 200.0, "p": 0.8},
      {"x": 105.0, "y": 205.0, "p": 1.0}
    ]
  }
}
```

### 2. `draw_shape`
Client draws a geometry vector shape.
```json
{
  "event": "draw_shape",
  "session_code": "PIN123",
  "data": {
    "shape_id": "uuid-string",
    "shape_type": "rectangle",
    "start_x": 100.0,
    "start_y": 100.0,
    "end_x": 300.0,
    "end_y": 250.0,
    "color": "0xFFFF5722",
    "stroke_width": 3.0,
    "fill_color": "0x33FF5722"
  }
}
```

### 3. `canvas_action`
Standard actions to sync layout resets or steps.
```json
{
  "event": "canvas_action",
  "session_code": "PIN123",
  "data": {
    "action": "clear" // Options: "clear", "undo", "redo"
  }
}
```
