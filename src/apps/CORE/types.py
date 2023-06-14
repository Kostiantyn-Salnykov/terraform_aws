import typing

from pydantic import BaseModel

SchemaType = typing.TypeVar("SchemaType", bound=BaseModel)
