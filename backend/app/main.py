import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import engine, Base, get_db
from app.api import auth, boards, sessions, exports
from app.services.websocket_manager import manager
from app.models import models

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("smartboard_backend")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Create tables if they do not exist
    logger.info("Initializing Database tables...")
    Base.metadata.create_all(bind=engine)
    yield
    # Shutdown: Clean up if needed
    logger.info("Shutting down...")

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# CORS middleware for Web App connectivity
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(boards.router, prefix=settings.API_V1_STR)
app.include_router(sessions.router, prefix=settings.API_V1_STR)
app.include_router(exports.router, prefix=settings.API_V1_STR)

@app.get("/")
def read_root():
    return {"message": "Welcome to SmartBoard Go Backend Server", "status": "healthy"}

@app.websocket("/ws/{session_code}")
async def websocket_endpoint(websocket: WebSocket, session_code: str, db: Session = Depends(get_db)):
    """
    Handles live canvas drawing updates over WebSockets.
    Automatically pushes history to new connections.
    """
    # Verify session code is active in database before accepting connection
    session_record = db.query(models.Session).filter(
        models.Session.session_code == session_code,
        models.Session.is_active == True
    ).first()
    if not session_record:
        await websocket.close(code=1008) # Policy Violation close code
        logger.warning(f"WebSocket connection rejected: invalid/inactive session code {session_code}")
        return

    await manager.connect(websocket, session_code)
    logger.info(f"WebSocket connected for session: {session_code}")
    
    # 1. Sync historical drawings for this session to the newly connected client
    history = await manager.get_session_strokes(session_code)
    if history:
        await websocket.send_json({
            "event": "sync_history",
            "session_code": session_code,
            "data": history
        })
    else:
        # Fallback: query database for board strokes if in-memory cache is cold
        session_record = db.query(models.Session).filter(
            models.Session.session_code == session_code,
            models.Session.is_active == True
        ).first()
        if session_record:
            drawing_record = db.query(models.Drawing).filter(
                models.Drawing.board_id == session_record.board_id
            ).first()
            if drawing_record and drawing_record.stroke_data:
                db_history = drawing_record.stroke_data
                # Populate in-memory cache
                for stroke in db_history:
                    await manager.save_stroke_memory(session_code, {
                        "event": "draw_stroke",
                        "data": stroke
                    })
                await websocket.send_json({
                    "event": "sync_history",
                    "session_code": session_code,
                    "data": db_history
                })

    try:
        while True:
            # Receive drawing/shape JSON payloads
            data = await websocket.receive_json()
            
            # 2. Parse event and update local/memory cache
            event_type = data.get("event")
            
            if event_type == "join_classroom":
                user_info = data.get("data", {})
                name = user_info.get("name", "User")
                role = user_info.get("role", "student")
                await manager.register_user(websocket, session_code, name, role)
                continue
                
            await manager.save_stroke_memory(session_code, data)
            
            # 3. Broadcast to all other sessions (e.g. phone draws, laptop/web displays)
            await manager.publish_to_session(data, session_code, exclude_websocket=websocket)
            
            # 4. Periodically save to database (or write on stroke completions)
            if event_type in ("draw_stroke", "draw_shape", "canvas_action"):
                session_record = db.query(models.Session).filter(
                    models.Session.session_code == session_code,
                    models.Session.is_active == True
                ).first()
                if session_record:
                    drawing_record = db.query(models.Drawing).filter(
                        models.Drawing.board_id == session_record.board_id
                    ).first()
                    if not drawing_record:
                        drawing_record = models.Drawing(board_id=session_record.board_id, stroke_data=[])
                        db.add(drawing_record)
                    
                    # Store current session strokes in database JSON list
                    drawing_record.stroke_data = await manager.get_session_strokes(session_code)
                    db.commit()
                    
    except WebSocketDisconnect:
        await manager.disconnect(websocket, session_code)
        logger.info(f"WebSocket disconnected for session: {session_code}")
    except Exception as e:
        await manager.disconnect(websocket, session_code)
        logger.error(f"WebSocket error for session {session_code}: {str(e)}")
