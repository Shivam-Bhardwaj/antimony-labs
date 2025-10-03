"""
Antimony Labs - Paper-Trail API
Main application server for LLM coordination and user interaction
"""

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import asyncio
import json
from datetime import datetime
import redis.asyncio as redis
from qdrant_client import QdrantClient
import anthropic
import openai

app = FastAPI(title="Antimony Labs - Paper-Trail API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global connections (initialized on startup)
redis_client = None
qdrant_client = None


class IdeaSubmission(BaseModel):
    """User submits an idea in plain English"""
    title: str
    description: str
    category: Optional[str] = None


class LLMMessage(BaseModel):
    """Inter-LLM communication message"""
    from_llm: str  # claude-rpi5, codex-rpi5, claude-hpc, codex-hpc
    to_llm: str
    task: str
    context: Dict[str, Any]
    session_id: str
    priority: int = 1


class PaperTrailUpdate(BaseModel):
    """Update to the paper-trail brain"""
    entity_type: str
    entity_id: str
    action: str
    data: Dict[str, Any]


# ============================================================================
# STARTUP & SHUTDOWN
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize connections on startup"""
    global redis_client, qdrant_client

    # Redis connection
    redis_client = await redis.from_url("redis://redis:6379", decode_responses=True)

    # Qdrant connection
    qdrant_client = QdrantClient(url="http://qdrant:6333")

    print("✅ Paper-Trail API started successfully")
    print("🧠 Connected to Redis (LLM communication)")
    print("🔍 Connected to Qdrant (vector search)")


@app.on_event("shutdown")
async def shutdown_event():
    """Clean up connections on shutdown"""
    if redis_client:
        await redis_client.close()
    print("👋 Paper-Trail API shutdown")


# ============================================================================
# USER INTERACTION ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    """Health check"""
    return {
        "status": "online",
        "service": "antimony-labs-paper-trail",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.post("/api/ideas/submit")
async def submit_idea(idea: IdeaSubmission):
    """
    User submits an idea in plain English
    System automatically:
    1. Analyzes uniqueness
    2. Generates PRD (via LLM coordination)
    3. Creates initial paper-trail entry
    """
    session_id = f"idea-{datetime.utcnow().timestamp()}"

    # Publish to LLM coordination channel
    message = {
        "session_id": session_id,
        "task": "process_new_idea",
        "idea": idea.dict(),
        "timestamp": datetime.utcnow().isoformat(),
        "from": "user_api"
    }

    await redis_client.publish("llm:coordination", json.dumps(message))

    return {
        "session_id": session_id,
        "status": "processing",
        "message": "Your idea is being analyzed. Claude and Codex are working together!"
    }


@app.get("/api/ideas/{idea_id}")
async def get_idea(idea_id: str):
    """Get idea details and current status"""
    # TODO: Query PostgreSQL for idea details
    return {"idea_id": idea_id, "status": "in_development"}


# ============================================================================
# INTER-LLM COMMUNICATION
# ============================================================================

@app.post("/api/llm/message")
async def send_llm_message(message: LLMMessage):
    """
    Send a message from one LLM to another
    Used by Claude Code and Codex instances to coordinate
    """
    channel = f"llm:{message.to_llm}"

    await redis_client.publish(channel, json.dumps({
        "from": message.from_llm,
        "to": message.to_llm,
        "task": message.task,
        "context": message.context,
        "session_id": message.session_id,
        "timestamp": datetime.utcnow().isoformat()
    }))

    return {"status": "sent", "channel": channel}


@app.websocket("/ws/llm/{llm_name}")
async def llm_websocket(websocket: WebSocket, llm_name: str):
    """
    WebSocket endpoint for LLM instances to receive messages in real-time
    Each LLM connects to its own channel
    """
    await websocket.accept()

    # Subscribe to this LLM's channel
    pubsub = redis_client.pubsub()
    await pubsub.subscribe(f"llm:{llm_name}", "llm:coordination")

    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                await websocket.send_text(message["data"])
    except WebSocketDisconnect:
        await pubsub.unsubscribe(f"llm:{llm_name}")
        print(f"🔌 {llm_name} disconnected")


# ============================================================================
# PAPER-TRAIL BRAIN UPDATES
# ============================================================================

@app.post("/api/paper-trail/update")
async def update_paper_trail(update: PaperTrailUpdate):
    """
    Update the paper-trail brain
    Called whenever contributions are made
    """
    # Store in Redis for immediate access
    trail_key = f"trail:{update.entity_type}:{update.entity_id}"

    trail_data = {
        "action": update.action,
        "data": update.data,
        "timestamp": datetime.utcnow().isoformat()
    }

    await redis_client.lpush(trail_key, json.dumps(trail_data))
    await redis_client.expire(trail_key, 86400)  # 24 hour cache

    # TODO: Also update PostgreSQL for persistence
    # TODO: Generate embeddings and store in Qdrant

    return {"status": "updated", "key": trail_key}


@app.get("/api/paper-trail/{entity_type}/{entity_id}")
async def get_paper_trail(entity_type: str, entity_id: str):
    """Get the paper-trail history for an entity"""
    trail_key = f"trail:{entity_type}:{entity_id}"
    trail = await redis_client.lrange(trail_key, 0, -1)

    return {
        "entity_type": entity_type,
        "entity_id": entity_id,
        "trail": [json.loads(item) for item in trail]
    }


# ============================================================================
# SYSTEM STATUS
# ============================================================================

@app.get("/api/system/status")
async def system_status():
    """Check status of all connected LLMs and services"""
    # Check which LLMs are currently connected
    llm_instances = ["claude-rpi5", "codex-rpi5", "claude-hpc", "codex-hpc"]
    status = {}

    for llm in llm_instances:
        # Check if LLM has an active presence key
        active = await redis_client.exists(f"presence:{llm}")
        status[llm] = "online" if active else "offline"

    return {
        "timestamp": datetime.utcnow().isoformat(),
        "llm_instances": status,
        "services": {
            "redis": "online" if redis_client else "offline",
            "qdrant": "online" if qdrant_client else "offline"
        }
    }


@app.post("/api/system/llm/heartbeat/{llm_name}")
async def llm_heartbeat(llm_name: str):
    """LLM instances send heartbeat to indicate they're online"""
    await redis_client.setex(f"presence:{llm_name}", 60, "1")  # 60 second TTL
    return {"status": "acknowledged", "llm": llm_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
