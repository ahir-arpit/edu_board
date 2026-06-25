from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

# Token schemas
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None
    user_id: Optional[str] = None

# User schemas
class UserBase(BaseModel):
    email: EmailStr
    name: str
    role: Optional[str] = "user"

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserOut(UserBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# Board schemas
class BoardBase(BaseModel):
    title: str = "Untitled Board"

class BoardCreate(BoardBase):
    pass

class BoardOut(BoardBase):
    id: str
    owner_id: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# Session schemas
class SessionBase(BaseModel):
    board_id: str

class SessionCreate(SessionBase):
    pass

class SessionOut(SessionBase):
    id: str
    session_code: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class SessionJoin(BaseModel):
    session_code: str

# Drawing schemas
class DrawingUpdate(BaseModel):
    stroke_data: List[Dict[str, Any]]
