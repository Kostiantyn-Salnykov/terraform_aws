from fastapi import APIRouter, FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from loggers import get_logger, setup_logging
from settings import Settings

from .CORE.enums import JSENDStatus
from .CORE.schemas import JSENDOutSchema

logger = get_logger(name=__name__)

app = FastAPI(
    debug=True,
    title="FastAPI Quickstart",
    description="",
    version="0.0.1",
    openapi_url="/openapi.json" if Settings.ENABLE_OPENAPI else None,
    redoc_url=None,  # Redoc disabled
    docs_url="/docs/" if Settings.ENABLE_OPENAPI else None,
    default_response_class=ORJSONResponse,
)

app.add_middleware(
    middleware_class=CORSMiddleware,
    allow_origins=Settings.CORS_ALLOW_ORIGINS,
    allow_credentials=Settings.CORS_ALLOW_CREDENTIALS,
    allow_methods=Settings.CORS_ALLOW_METHODS,
    allow_headers=Settings.CORS_ALLOW_HEADERS,
)  # №2
app.add_middleware(middleware_class=ProxyHeadersMiddleware, trusted_hosts=Settings.TRUSTED_HOSTS)  # №1


@app.on_event(event_type="startup")
def enable_logging() -> None:
    setup_logging()
    logger.debug(msg="Logging configuration completed.")


api_router = APIRouter()


@api_router.get(
    path="/",
    response_model=JSENDOutSchema,
    status_code=status.HTTP_200_OK,
    summary="Container health check.",
    description="Health check endpoint.",
)
async def container_healthcheck() -> ORJSONResponse:
    """Check that API endpoints works properly.

    Returns:
        ORJSONResponse: json object with JSENDResponseSchema body.
    """
    logger.debug(msg="Container Health check.")
    return ORJSONResponse(
        content={
            "status": JSENDStatus.SUCCESS,
            "data": None,
            "message": "Health check.",
            "code": status.HTTP_200_OK,
        },
        status_code=status.HTTP_200_OK,
    )


@api_router.get(
    path="/is_ready/",
    response_model=JSENDOutSchema,
    status_code=status.HTTP_200_OK,
    summary="ALB Health check.",
    description="Health check endpoint.",
)
async def alb_healthcheck() -> ORJSONResponse:
    """Check that API endpoints works properly.

    Returns:
        ORJSONResponse: json object with JSENDResponseSchema body.
    """
    logger.debug(msg="ALB Health check.")
    return ORJSONResponse(
        content={
            "status": JSENDStatus.SUCCESS,
            "data": None,
            "message": "Health check.",
            "code": status.HTTP_200_OK,
        },
        status_code=status.HTTP_200_OK,
    )


app.include_router(router=api_router)


if __name__ == "__main__":  # pragma: no cover
    # Use this for debugging purposes only
    import uvicorn

    uvicorn.run(
        app="apps.main:app",
        host=Settings.HOST,
        port=Settings.PORT,
        loop="uvloop",
        reload=True,  # FIXME: PyCharm debugger error: https://youtrack.jetbrains.com/issue/PY-57217
        reload_delay=5,
        log_level=Settings.LOG_LEVEL,
        use_colors=Settings.LOG_USE_COLORS,
    )
