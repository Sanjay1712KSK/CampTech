import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from database import db
from routes import auth as auth_router
from routes import verification as verification_router
from routes import digilocker as digilocker_router
from routes import environment as environment_router
from routes import gig as gig_router
from utils.response import error_response

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('gig_insurance_backend')

app = FastAPI(title='Gig Insurance API', version='1.0.0')

app.include_router(auth_router.router)
app.include_router(verification_router.router)
app.include_router(digilocker_router.router)
app.include_router(environment_router.router)
app.include_router(gig_router.router)


@app.on_event('startup')
def on_startup():
    logger.info('Starting service and creating database tables if needed')
    db.ensure_schema()


@app.get('/')
def home():
    return {'message': 'Backend is running!!!'}
