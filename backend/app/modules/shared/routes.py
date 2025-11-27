"""
Rutas compartidas para catálogos y recursos comunes
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from app.core.database import get_async_db

router = APIRouter(prefix="/shared", tags=["Shared"])


@router.get("/relationships")
async def get_relationships(
    active_only: bool = True,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Obtiene el catálogo de relaciones (para avales y beneficiarios)
    
    Args:
        active_only: Si True, solo relaciones activas
        
    Returns:
        Lista de relaciones disponibles
    """
    query = text("""
        SELECT id, name, description, active
        FROM relationships
        WHERE (:active_only = FALSE OR active = TRUE)
        ORDER BY name
    """)
    
    result = await db.execute(query, {"active_only": active_only})
    rows = result.fetchall()
    
    return {
        "success": True,
        "data": [
            {
                "id": row[0],
                "name": row[1],
                "description": row[2],
                "active": row[3]
            }
            for row in rows
        ]
    }
