import pydantic


def main(event, context):
    print(f"Pydantic version == {pydantic.__version__}")
    print(event)
    print(context)
    return {"Hello": "World!"}
