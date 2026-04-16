from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.admin_schema import (
    AdminClaimsStatsResponse,
    AdminFinancialsResponse,
    AdminFraudStatsResponse,
    AdminLoginRequest,
    AdminLoginResponse,
    AdminOverviewResponse,
    AdminPredictionsResponse,
    AdminRiskStatsResponse,
)
from services.admin_service import (
    admin_login,
    get_claims_stats,
    get_current_admin,
    get_financials,
    get_fraud_stats,
    get_overview,
    get_predictions,
    get_risk_stats,
)

router = APIRouter(prefix='/admin', tags=['admin'])


@router.post('/login', response_model=AdminLoginResponse)
async def admin_login_endpoint(payload: AdminLoginRequest):
    return admin_login(email=payload.email, password=payload.password)


@router.get('/overview', response_model=AdminOverviewResponse)
async def admin_overview_endpoint(
    db: Session = Depends(get_db),
    _admin: dict = Depends(get_current_admin),
):
    return get_overview(db)


@router.get('/fraud-stats', response_model=AdminFraudStatsResponse)
async def admin_fraud_stats_endpoint(
    db: Session = Depends(get_db),
    _admin: dict = Depends(get_current_admin),
):
    return get_fraud_stats(db)


@router.get('/claims-stats', response_model=AdminClaimsStatsResponse)
async def admin_claims_stats_endpoint(
    db: Session = Depends(get_db),
    _admin: dict = Depends(get_current_admin),
):
    return get_claims_stats(db)


@router.get('/risk-stats', response_model=AdminRiskStatsResponse)
async def admin_risk_stats_endpoint(
    db: Session = Depends(get_db),
    _admin: dict = Depends(get_current_admin),
):
    return get_risk_stats(db)


@router.get('/financials', response_model=AdminFinancialsResponse)
async def admin_financials_endpoint(
    db: Session = Depends(get_db),
    _admin: dict = Depends(get_current_admin),
):
    return get_financials(db)


@router.get('/predictions', response_model=AdminPredictionsResponse)
async def admin_predictions_endpoint(
    db: Session = Depends(get_db),
    _admin: dict = Depends(get_current_admin),
):
    return get_predictions(db)
