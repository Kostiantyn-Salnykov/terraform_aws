import functools
import logging
import pathlib

from pydantic import BaseSettings, Extra, Field

PROJECT_BASE_DIR = pathlib.Path(__file__).resolve().parent


class MainSettings(BaseSettings):
    # Back-end settings
    DEBUG: bool = Field(default=False)
    SHOW_SETTINGS: bool = Field(default=False)
    ENABLE_OPENAPI: bool = Field(default=False)
    HOST: str = Field(default="0.0.0.0")
    PORT: int = Field(default=8000)
    WORKERS_COUNT: int = Field(default=1)
    DATETIME_FORMAT: str = Field(default="%Y-%m-%d %H:%M:%S")
    TRUSTED_HOSTS: list[str] = Field(default=["*"])
    # CORS settings
    CORS_ALLOW_CREDENTIALS: bool = Field(default=True)
    CORS_ALLOW_HEADERS: list[str] = Field(default=["*"])
    CORS_ALLOW_METHODS: list[str] = Field(default=["*"])
    CORS_ALLOW_ORIGINS: list[str] = Field(default=["*"])
    # Logging settings
    LOG_LEVEL: int = Field(default=logging.WARNING)
    LOG_USE_COLORS: bool = Field(default=False)

    class Config(BaseSettings.Config):
        extra = Extra.ignore
        env_file = ".env"
        env_file_encoding = "UTF-8"
        env_nested_delimiter = "__"


@functools.lru_cache()
def get_settings() -> MainSettings:
    return MainSettings()


Settings: MainSettings = get_settings()

if Settings.DEBUG and Settings.SHOW_SETTINGS:
    import pprint  # noqa

    pprint.pprint(Settings.dict())
