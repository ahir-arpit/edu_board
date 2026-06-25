import random
import string
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import models
from app.schemas import schemas
from app.api.auth import get_current_user

router = APIRouter(prefix="/sessions", tags=["sessions"])

def generate_session_code(db: Session) -> str:
    """
    Generates a unique 6-character alphanumeric code for the pairing session.
    """
    characters = string.ascii_uppercase + string.digits
    while True:
        code = "".join(random.choices(characters, k=6))
        # Ensure it is unique among active sessions
        exists = db.query(models.Session).filter(
            models.Session.session_code == code,
            models.Session.is_active == True
        ).first()
        if not exists:
            return code

@router.post("/create", response_model=schemas.SessionOut)
def create_session(
    session_in: schemas.SessionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Create a pairing session for a board. Only the owner can create sessions.
    """
    board = db.query(models.Board).filter(
        models.Board.id == session_in.board_id,
        models.Board.owner_id == current_user.id
    ).first()
    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Board not found or access denied"
        )
    
    # Deactivate any existing active sessions for this board
    existing_sessions = db.query(models.Session).filter(
        models.Session.board_id == board.id,
        models.Session.is_active == True
    ).all()
    for s in existing_sessions:
        s.is_active = False
    
    session_code = generate_session_code(db)
    session = models.Session(
        session_code=session_code,
        board_id=board.id,
        is_active=True
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session

@router.post("/join", response_model=schemas.SessionOut)
def join_session(
    join_in: schemas.SessionJoin,
    db: Session = Depends(get_db)
):
    """
    Join an active pairing session using a session code.
    Returns the session info and board mapping.
    """
    session = db.query(models.Session).filter(
        models.Session.session_code == join_in.session_code,
        models.Session.is_active == True
    ).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active session code not found or expired"
        )
    return session
