from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.models import models
from app.schemas import schemas
from app.api.auth import get_current_user

router = APIRouter(prefix="/boards", tags=["boards"])

@router.get("", response_model=List[schemas.BoardOut])
def get_boards(
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """
    Get all boards owned by the current user.
    """
    return db.query(models.Board).filter(models.Board.owner_id == current_user.id).all()

@router.post("", response_model=schemas.BoardOut, status_code=status.HTTP_201_CREATED)
def create_board(
    board_in: schemas.BoardCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """
    Create a new whiteboard.
    """
    board = models.Board(
        title=board_in.title,
        owner_id=current_user.id
    )
    db.add(board)
    db.commit()
    db.refresh(board)
    
    # Initialize an empty drawing record for this board
    drawing = models.Drawing(board_id=board.id, stroke_data=[])
    db.add(drawing)
    db.commit()
    
    return board

@router.get("/{board_id}", response_model=schemas.BoardOut)
def get_board(
    board_id: str, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """
    Get board details by ID.
    """
    board = db.query(models.Board).filter(
        models.Board.id == board_id, 
        models.Board.owner_id == current_user.id
    ).first()
    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="Board not found or access denied"
        )
    return board

@router.delete("/{board_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_board(
    board_id: str, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """
    Delete a whiteboard.
    """
    board = db.query(models.Board).filter(
        models.Board.id == board_id, 
        models.Board.owner_id == current_user.id
    ).first()
    if not board:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="Board not found or access denied"
        )
    db.delete(board)
    db.commit()
    return None
