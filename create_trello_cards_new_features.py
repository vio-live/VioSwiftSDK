#!/usr/bin/env python3
"""
Script to create Trello cards for new features implemented since last merge.
"""

import asyncio
import os
import sys
from typing import Dict, List, Optional

# Add trello-mcp-server to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../Documents/GitHub/trello-mcp-server'))

from dotenv import load_dotenv
from server.services.board import BoardService
from server.services.list import ListService
from server.services.card import CardService
from server.services.checklist import ChecklistService
from server.utils.trello_api import TrelloClient

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../Documents/GitHub/trello-mcp-server/.env'))

# Initialize Trello client
api_key = os.getenv("TRELLO_API_KEY")
token = os.getenv("TRELLO_TOKEN")
if not api_key or not token:
    raise ValueError("TRELLO_API_KEY and TRELLO_TOKEN must be set")

client = TrelloClient(api_key=api_key, token=token)
board_service = BoardService(client)
list_service = ListService(client)
card_service = CardService(client)
checklist_service = ChecklistService(client)

BOARD_ID = "5dea6d99c0ea505b4c3a435e"  # Reachu Dev
BACKLOG_LIST_ID = "645e0787a4ef6845516d172b"  # List ID from previous usage

# Tag to label color mapping
TAG_COLOR_MAP = {
    "backend": "red",
    "swift": "blue",
    "kotlin": "green",
    "sdk": "orange",
    "database": "purple",
    "api": "pink",
    "websocket": "yellow",
    "ui": "sky",
    "network": "lime",
    "realtime": "black",
    "timeline": "red",
    "chat": "blue",
    "polls": "green",
    "video": "orange",
    "integration": "purple",
    "auth": "pink",
    "admin": "yellow",
    "demo": "sky",
    "migration": "lime",
    "setup": "black",
    "configuration": "red",
    "documentation": "blue",
    "testing": "green",
    "priority-high": "red",
    "priority-medium": "yellow",
    "priority-low": "green",
}


async def get_or_create_label(board_id: str, tag: str) -> Optional[str]:
    """Get or create a label for a tag. Returns label ID."""
    try:
        labels = await board_service.get_board_labels(board_id)
        
        for label in labels:
            if label.name and label.name.lower() == tag.lower():
                return label.id
        
        color = TAG_COLOR_MAP.get(tag.lower(), "grey")
        label_data = await client.POST(f"/labels", data={
            "name": tag,
            "color": color,
            "idBoard": board_id,
        })
        return label_data["id"]
    except Exception as e:
        print(f"Error getting/creating label for {tag}: {e}")
        return None


async def create_card_with_checklist(
    list_id: str,
    name: str,
    desc: str,
    checklist_items: List[str],
    label_ids: List[str],
) -> Optional[str]:
    """Create a card with checklist items."""
    try:
        card = await card_service.create_card(
            idList=list_id,
            name=name,
            desc=desc,
            idLabels=",".join(label_ids) if label_ids else None,
        )
        
        if checklist_items and card.id:
            checklist = await checklist_service.create_checklist(card.id, name="Checklist")
            if checklist:
                checklist_id = checklist["id"]
                for item in checklist_items:
                    await checklist_service.add_checkitem(checklist_id, item)
        
        return card.id
    except Exception as e:
        print(f"Error creating card: {e}")
        return None


# Cards to create
NEW_FEATURES_CARDS = [
    {
        "name": "Swift SDK: Video Synchronization System",
        "desc": """Implement video synchronization for polls and contests

**Archivos creados/modificados:**
- `Sources/ReachuEngagementSystem/Managers/VideoSyncManager.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Models/EngagementModels.swift` (actualizado)
- `Sources/ReachuEngagementSystem/Managers/EngagementManager.swift` (actualizado)
- `Sources/ReachuEngagementSystem/Data/BackendEngagementRepository.swift` (actualizado)
- `Demo/Viaplay/Viaplay/Views/ViaplayCastingActiveView.swift` (actualizado)
- `Documentation/VIDEO_SYNC_API_SPEC.md` (nuevo)

**Funcionalidad:**
- Sincronización de polls/contests con tiempo de reproducción del video
- Soporte para videos en vivo y grabados
- Timestamps relativos al inicio del partido (videoStartTime, videoEndTime)
- Fallback a timestamps absolutos para backward compatibility

**Estado:** ✅ Implementado en SDK""",
        "checklist": [
            "VideoSyncManager creado y funcionando",
            "Modelos actualizados con campos de video sync",
            "EngagementManager integrado con VideoSyncManager",
            "BackendEngagementRepository parsea nuevos campos",
            "ViaplayCastingActiveView integrado con VideoSyncManager",
            "Documentación VIDEO_SYNC_API_SPEC.md creada"
        ],
        "tags": ["swift", "sdk", "video", "polls", "integration", "priority-high"],
    },
    {
        "name": "Swift SDK: Dynamic Configuration System",
        "desc": """Implement dynamic configuration management from backend

**Archivos creados/modificados:**
- `Sources/ReachuCore/Managers/DynamicConfigurationManager.swift` (nuevo)
- `Sources/ReachuCore/Models/DynamicConfigModels.swift` (nuevo)
- `Sources/ReachuCore/Network/ConfigAPIClient.swift` (nuevo)
- `Sources/ReachuCore/Managers/CampaignManager.swift` (actualizado)
- `Sources/ReachuCore/Configuration/ReachuConfiguration.swift` (actualizado)
- `Documentation/BACKEND_API_SPEC.md` (nuevo)
- `Documentation/BACKEND_IMPLEMENTATION_GUIDE.md` (nuevo)
- `Documentation/BACKEND_QA_RESPONSES.md` (nuevo)

**Funcionalidad:**
- Carga de configuración dinámica desde backend
- Caché de configuraciones con TTL
- Invalidación de caché vía WebSocket
- Configuración efectiva que prioriza dinámica sobre estática
- Soporte para brand, engagement, UI, theme, feature flags, localization

**Estado:** ✅ Implementado en SDK""",
        "checklist": [
            "DynamicConfigurationManager creado",
            "DynamicConfigModels definidos",
            "ConfigAPIClient implementado",
            "CampaignManager integrado",
            "ReachuConfiguration actualizado con effectiveBrandConfiguration",
            "Documentación BACKEND_API_SPEC.md creada",
            "Documentación BACKEND_IMPLEMENTATION_GUIDE.md creada",
            "Documentación BACKEND_QA_RESPONSES.md creada"
        ],
        "tags": ["swift", "sdk", "configuration", "api", "backend", "priority-high"],
    },
    {
        "name": "Swift SDK: Engagement Repository Pattern",
        "desc": """Refactor engagement system to use repository pattern for demo/backend switching

**Archivos creados/modificados:**
- `Sources/ReachuEngagementSystem/Data/EngagementRepositoryProtocol.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Data/BackendEngagementRepository.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Data/DemoEngagementRepository.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Managers/EngagementManager.swift` (refactorizado)
- `Demo/Viaplay/Viaplay/ViaplayApp.swift` (actualizado)

**Funcionalidad:**
- Repository pattern para abstraer fuente de datos
- Demo mode usando datos mock
- Backend mode usando API REST
- Cambio dinámico entre modos según configuración
- Soporte para múltiples partidos simultáneos

**Estado:** ✅ Implementado en SDK""",
        "checklist": [
            "EngagementRepositoryProtocol definido",
            "BackendEngagementRepository implementado",
            "DemoEngagementRepository implementado",
            "EngagementManager refactorizado para usar repositorios",
            "Demo app configurada con closures para conversión de eventos"
        ],
        "tags": ["swift", "sdk", "polls", "contests", "demo", "backend", "priority-high"],
    },
    {
        "name": "Backend: Video Sync API Implementation",
        "desc": """Implement backend API endpoints for video synchronization

**Endpoints a implementar:**
- `GET /v1/engagement/polls` - Agregar campos videoStartTime, videoEndTime, matchStartTime
- `GET /v1/engagement/contests` - Agregar campos videoStartTime, videoEndTime, matchStartTime
- `GET /v1/engagement/config` - Agregar matchStartTime

**Cambios en base de datos:**
- Agregar columnas video_start_time, video_end_time, match_start_time a polls
- Agregar columnas video_start_time, video_end_time, match_start_time a contests
- Asegurar que matches table tiene match_start_time

**Documentación:** Ver `Documentation/VIDEO_SYNC_API_SPEC.md`

**Estado:** ⏳ Pendiente implementación backend""",
        "checklist": [
            "Actualizar esquema de base de datos (polls y contests)",
            "Implementar campos videoStartTime/videoEndTime en endpoints",
            "Implementar campo matchStartTime en endpoints",
            "Actualizar queries SQL para incluir nuevos campos",
            "Probar endpoints con datos de ejemplo",
            "Validar cálculo de timestamps relativos"
        ],
        "tags": ["backend", "api", "database", "video", "polls", "contests", "priority-high"],
    },
    {
        "name": "Backend: Dynamic Configuration API Implementation",
        "desc": """Implement backend API endpoints for dynamic configuration

**Endpoints a implementar:**
- `GET /v1/campaigns/{campaignId}/config` - Configuración completa de campaña
- `GET /v1/engagement/config` - Configuración de engagement
- `GET /v1/localization/{language}` - Traducciones
- WebSocket event `config:updated` - Invalidación de caché

**Cambios en base de datos:**
- Crear tablas según BACKEND_IMPLEMENTATION_GUIDE.md
- Implementar queries para configuraciones dinámicas
- Implementar sistema de caché con TTL

**Documentación:** Ver `Documentation/BACKEND_API_SPEC.md` y `Documentation/BACKEND_IMPLEMENTATION_GUIDE.md`

**Estado:** ⏳ Pendiente implementación backend""",
        "checklist": [
            "Crear tablas según BACKEND_IMPLEMENTATION_GUIDE.md",
            "Implementar endpoint GET /v1/campaigns/{campaignId}/config",
            "Implementar endpoint GET /v1/engagement/config",
            "Implementar endpoint GET /v1/localization/{language}",
            "Implementar evento WebSocket config:updated",
            "Implementar sistema de caché con TTL",
            "Probar endpoints con datos de ejemplo"
        ],
        "tags": ["backend", "api", "database", "configuration", "websocket", "priority-high"],
    },
]


async def main():
    """Main function to create all cards."""
    print("Starting card creation process...")
    
    # Use the known list ID
    backlog_list_id = BACKLOG_LIST_ID
    print(f"Using list ID: {backlog_list_id}")
    
    # Verify list exists
    try:
        backlog_list = await list_service.get_list(backlog_list_id)
        print(f"Found list: {backlog_list.name} (ID: {backlog_list.id})")
    except Exception as e:
        print(f"ERROR: Could not access list {backlog_list_id}: {e}")
        # Try to get lists from board to find backlog
        print(f"Getting lists for board {BOARD_ID}...")
        lists = await list_service.get_lists(BOARD_ID)
        print(f"Available lists: {[f'{lst.name} (ID: {lst.id})' for lst in lists]}")
        return
    
    # Get or create labels for all tags
    print("Getting/creating labels...")
    tag_to_label_id: Dict[str, str] = {}
    all_tags = set()
    for task in NEW_FEATURES_CARDS:
        all_tags.update(task["tags"])
    
    for tag in all_tags:
        label_id = await get_or_create_label(BOARD_ID, tag)
        if label_id:
            tag_to_label_id[tag] = label_id
            print(f"  Label '{tag}': {label_id}")
    
    # Create cards
    print(f"\nCreating {len(NEW_FEATURES_CARDS)} cards...")
    created_count = 0
    for i, task in enumerate(NEW_FEATURES_CARDS, 1):
        print(f"\n[{i}/{len(NEW_FEATURES_CARDS)}] Creating: {task['name']}")
        
        # Get label IDs for this task
        label_ids = [tag_to_label_id[tag] for tag in task["tags"] if tag in tag_to_label_id]
        
        # Create card with checklist
        card_id = await create_card_with_checklist(
            list_id=backlog_list_id,
            name=task["name"],
            desc=task["desc"],
            checklist_items=task["checklist"],
            label_ids=label_ids,
        )
        
        if card_id:
            created_count += 1
            print(f"  ✅ Created card ID: {card_id}")
        else:
            print(f"  ❌ Failed to create card")
        
        # Small delay to avoid rate limiting
        await asyncio.sleep(0.5)
    
    print(f"\n\n✅ Completed! Created {created_count}/{len(NEW_FEATURES_CARDS)} cards.")
    
    # Close client
    await client.close()


if __name__ == "__main__":
    asyncio.run(main())
