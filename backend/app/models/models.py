import uuid
from sqlalchemy import Column, String, ForeignKey, Boolean, JSON, DateTime, Integer
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True) # Nullable for OAuth/Firebase Sign-In
    role = Column(String, default="user") # "teacher", "student", "user"
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    boards = relationship("Board", back_populates="owner", cascade="all, delete-orphan")

class Board(Base):
    __tablename__ = "boards"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, default="Untitled Board")
    owner_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    owner = relationship("User", back_populates="boards")
    sessions = relationship("Session", back_populates="board", cascade="all, delete-orphan")
    drawings = relationship("Drawing", back_populates="board", cascade="all, delete-orphan")

class Session(Base):
    __tablename__ = "sessions"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_code = Column(String, unique=True, index=True, nullable=False) # 6 digit code
    board_id = Column(String, ForeignKey("boards.id", ondelete="CASCADE"), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    board = relationship("Board", back_populates="sessions")

class Drawing(Base):
    __tablename__ = "drawings"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    board_id = Column(String, ForeignKey("boards.id", ondelete="CASCADE"), nullable=False)
    # stroke_data holds the raw strokes array, e.g., [{"id": "...", "points": [...], "color": "...", "width": ...}]
    stroke_data = Column(JSON, default=list) 
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), server_default=func.now())
    
    board = relationship("Board", back_populates="drawings")
