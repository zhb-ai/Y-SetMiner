from pydantic import BaseModel


class Settings(BaseModel):
    app_name: str = "SetMiner API"
    api_prefix: str = "/api"
    cors_origins: list[str] = ["http://localhost:5173"]


settings = Settings()
