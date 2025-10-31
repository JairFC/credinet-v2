"""
Application configuration using pydantic-settings.
Environment variables are loaded from .env file.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    
    Environment variables can be defined in .env file or system env.
    """
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )
    
    # Application
    app_name: str = "CrediNet Backend v2.0"
    debug: bool = False
    version: str = "2.0.0"
    
    # Database
    database_url: str
    db_echo: bool = False  # Log SQL queries
    
    # Security
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24  # 24 hours
    refresh_token_expire_days: int = 7  # 7 days
    
    # CORS
    cors_origins: str = "http://localhost:5173,http://localhost:3000"
    
    @property
    def cors_origins_list(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        return [origin.strip() for origin in self.cors_origins.split(",")]
    
    # API
    api_v1_prefix: str = "/api/v1"


# Global settings instance
settings = Settings()
