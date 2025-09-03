import asyncio
import os
import re
import signal
from contextlib import asynccontextmanager, AsyncExitStack
from typing import AsyncIterator

from fastapi import FastAPI, Request, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError


app = FastAPI(
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url=f"/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def shutdown_event(_signal, frame):
    os.kill(os.getpid(), signal.SIGTERM)



signal.signal(signal.SIGQUIT, shutdown_event)
signal.signal(signal.SIGINT, shutdown_event)

@app.get("/")
def read_root():
    return {"Hello": "World"}

#
# app.mount(
#     '/',
#     StaticFiles(directory=settings.STATIC_DIR, html=True),
#     name='static'
# )
# if __name__ == "__main__":
#     import uvicorn
#     uvicorn.run(app, host="0.0.0.0", port=5000, reload=True)
