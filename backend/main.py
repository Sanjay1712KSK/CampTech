import logging

from fastapi import FastAPI

from database import db
from routes import auth as auth_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('gig_insurance_backend')

app = FastAPI(title='Gig Insurance API', version='1.0.0')

app.include_router(auth_router.router)


@app.on_event('startup')
def on_startup():
    logger.info('Starting service and creating database tables if needed')
    db.Base.metadata.create_all(bind=db.engine)


@app.get('/')
def home():
    return {'message': 'Backend is running!!!'}
