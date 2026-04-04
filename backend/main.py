import logging
import os

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from database import db
from routes import auth as auth_router
from routes import bank as bank_router
from routes import claim as claim_router
from routes import digilocker as digilocker_router
from routes import environment as environment_router
from routes import gig as gig_router
from routes import payment as payment_router
from routes import premium as premium_router
from routes import risk as risk_router
from routes import support as support_router
from routes import simulation as simulation_router
from utils.response import error_response

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('gig_insurance_backend')

app = FastAPI(title='Gig Insurance API', version='1.0.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

app.include_router(auth_router.router)
app.include_router(bank_router.router)
app.include_router(claim_router.router)
app.include_router(digilocker_router.router)
app.include_router(environment_router.router)
app.include_router(gig_router.router)
app.include_router(payment_router.router)
app.include_router(premium_router.router)
app.include_router(risk_router.router)
app.include_router(support_router.router)
app.include_router(simulation_router.router)


@app.on_event('startup')
def on_startup():
    logger.info('Starting service and creating database tables if needed')
    db.ensure_schema()


@app.get('/health')
def health_check():
    return {'status': 'ok'}


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    message = exc.detail if isinstance(exc.detail, str) else 'Request failed'
    return JSONResponse(status_code=exc.status_code, content=error_response(message))


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    first_error = exc.errors()[0] if exc.errors() else {}
    location = '.'.join(str(part) for part in first_error.get('loc', []) if part != 'body')
    detail = first_error.get('msg', 'Invalid request')
    message = f'{location}: {detail}' if location else detail
    return JSONResponse(status_code=422, content=error_response(message))


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception('Unhandled exception: %s', exc)
    return JSONResponse(status_code=500, content=error_response('Something went wrong'))


@app.get('/')
def home():
    return {'message': 'Backend is running!!!'}


if __name__ == '__main__':
    import uvicorn

    host = os.getenv('API_HOST', '0.0.0.0')
    port = int(os.getenv('API_PORT', '8000'))
    uvicorn.run('main:app', host=host, port=port, reload=False)
