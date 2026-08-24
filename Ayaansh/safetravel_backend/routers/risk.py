# routers/risk.py
"""
Risk assessment router — stores P3's risk assessments.

Endpoints:
  POST /risk        — Save a risk assessment
  GET  /risk/latest — Most recent risk assessment for a session
"""
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import RiskAssessment
from schemas import RiskAssessmentCreate, RiskAssessmentResponse

router = APIRouter()


def _to_response(assessment: RiskAssessment) -> RiskAssessmentResponse:
    """Convert ORM model to Pydantic response, deserialising the reasons JSON."""
    reasons = []
    if assessment.reasons:
        try:
            reasons = json.loads(assessment.reasons)
        except (json.JSONDecodeError, TypeError):
            reasons = [assessment.reasons]

    return RiskAssessmentResponse(
        id=assessment.id,
        session_id=assessment.session_id,
        risk_level=assessment.risk_level,
        score=assessment.score,
        reasons=reasons,
        hotspot_id=assessment.hotspot_id,
        timestamp=assessment.timestamp,
    )


@router.post("", response_model=RiskAssessmentResponse, status_code=201)
def create_risk_assessment(payload: RiskAssessmentCreate, db: Session = Depends(get_db)):
    """
    Store a risk assessment from P3.
    reasons list is serialised to JSON for storage.
    """
    assessment = RiskAssessment(
        session_id=payload.session_id,
        risk_level=payload.risk_level,
        score=payload.score,
        reasons=json.dumps(payload.reasons),
        hotspot_id=payload.hotspot_id,
        timestamp=datetime.now(timezone.utc),
    )
    db.add(assessment)
    db.commit()
    db.refresh(assessment)
    return _to_response(assessment)


@router.get("/latest", response_model=RiskAssessmentResponse)
def get_latest_risk(session_id: str, db: Session = Depends(get_db)):
    """Return the most recent risk assessment for a given session_id."""
    assessment = (
        db.query(RiskAssessment)
        .filter(RiskAssessment.session_id == session_id)
        .order_by(RiskAssessment.timestamp.desc())
        .first()
    )
    if not assessment:
        raise HTTPException(
            status_code=404,
            detail=f"No risk assessment found for session_id='{session_id}'",
        )
    return _to_response(assessment)
