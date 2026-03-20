def error_response(message: str):
    return {
        'error': True,
        'message': message,
    }
