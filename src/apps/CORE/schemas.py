from typing import Generic

from fastapi import status as http_status
from pydantic import Field
from pydantic.generics import GenericModel

from ..CORE.enums import JSENDStatus
from ..CORE.types import SchemaType


class JSENDOutSchema(GenericModel, Generic[SchemaType]):
    """JSEND schema with 'success' status."""

    status: JSENDStatus = Field(default=JSENDStatus.SUCCESS)
    data: SchemaType | None = Field(default=None)
    message: str = Field(default=...)
    code: int = Field(default=http_status.HTTP_200_OK)
