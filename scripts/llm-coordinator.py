#!/usr/bin/env python3
"""
LLM Coordinator - Bridges Claude Code and Codex instances
This script runs on both RPi5 and HPC to enable inter-LLM communication
"""

import asyncio
import json
import sys
import subprocess
from datetime import datetime
from typing import Dict, Any
import redis.asyncio as redis
import websockets

# Configuration
INSTANCE_NAME = sys.argv[1] if len(sys.argv) > 1 else "claude-rpi5"

# Determine if this is HPC or RPi5 based on instance name
if "hpc" in INSTANCE_NAME:
    # HPC connects to RPi5 API via direct IP
    REDIS_URL = "redis://10.0.0.207:6379"
    API_URL = "ws://10.0.0.207:8000"
else:
    # RPi5 uses localhost
    REDIS_URL = "redis://localhost:6379"
    API_URL = "ws://localhost:8000"


class LLMCoordinator:
    """Coordinates communication between Claude Code and Codex"""

    def __init__(self, instance_name: str):
        self.instance_name = instance_name
        self.redis_client = None
        self.websocket = None
        self.running = True

    async def connect(self):
        """Connect to Redis and API WebSocket"""
        print(f"🔌 Connecting {self.instance_name}...")

        # Connect to Redis
        self.redis_client = await redis.from_url(REDIS_URL, decode_responses=True)

        # Connect to WebSocket
        self.websocket = await websockets.connect(f"{API_URL}/ws/llm/{self.instance_name}")

        print(f"✅ {self.instance_name} connected successfully")

    async def send_heartbeat(self):
        """Send periodic heartbeat to API"""
        import httpx
        async with httpx.AsyncClient() as client:
            while self.running:
                try:
                    await client.post(
                        f"http://localhost:8000/api/system/llm/heartbeat/{self.instance_name}"
                    )
                    await asyncio.sleep(30)  # Every 30 seconds
                except Exception as e:
                    print(f"⚠️  Heartbeat failed: {e}")
                    await asyncio.sleep(5)

    async def listen_for_tasks(self):
        """Listen for tasks from other LLMs"""
        print(f"👂 {self.instance_name} listening for tasks...")

        try:
            async for message in self.websocket:
                data = json.loads(message)
                print(f"\n📨 Received task: {data.get('task')}")
                print(f"   From: {data.get('from')}")
                print(f"   Session: {data.get('session_id')}")

                # Process the task
                await self.process_task(data)

        except websockets.exceptions.ConnectionClosed:
            print(f"🔌 Connection closed for {self.instance_name}")

    async def process_task(self, task_data: Dict[str, Any]):
        """Process a task received from another LLM"""
        task = task_data.get("task")
        context = task_data.get("context", {})
        session_id = task_data.get("session_id")

        print(f"\n⚙️  Processing: {task}")

        # Determine if this task is for Claude or Codex
        if "claude" in self.instance_name:
            result = await self.run_claude_task(task, context)
        elif "codex" in self.instance_name:
            result = await self.run_codex_task(task, context)
        else:
            result = {"error": "Unknown LLM type"}

        # Send result back
        await self.send_result(task_data.get("from"), session_id, result)

    async def run_claude_task(self, task: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run a task using Claude Code CLI
        This allows Claude to do reasoning, planning, file operations
        """
        print(f"🧠 Claude analyzing: {task}")

        # Example: Use Claude to analyze an idea
        if task == "process_new_idea":
            idea = context.get("idea", {})
            prompt = f"""
            Analyze this idea for uniqueness and quality:
            Title: {idea.get('title')}
            Description: {idea.get('description')}

            Rate uniqueness (0-1) and quality (0-1).
            Respond in JSON format.
            """

            # In a real implementation, you'd invoke Claude CLI or API here
            # For now, return a mock response
            return {
                "uniqueness_score": 0.75,
                "quality_score": 0.80,
                "analysis": "This is a novel approach with good potential.",
                "next_steps": ["Generate PRD", "Create initial code structure"]
            }

        return {"status": "completed", "task": task}

    async def run_codex_task(self, task: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run a task using Codex CLI
        This allows Codex to generate code, refactor, etc.
        """
        print(f"💻 Codex generating code for: {task}")

        # Example: Use Codex to generate code
        if task == "generate_code_structure":
            idea = context.get("idea", {})

            # In a real implementation, invoke Codex CLI here
            return {
                "files_created": [
                    "src/main.py",
                    "src/core/engine.py",
                    "README.md"
                ],
                "git_commit": "abc123",
                "status": "completed"
            }

        return {"status": "completed", "task": task}

    async def send_result(self, to_llm: str, session_id: str, result: Dict[str, Any]):
        """Send result to another LLM"""
        import httpx

        message = {
            "from_llm": self.instance_name,
            "to_llm": to_llm,
            "task": "task_result",
            "context": result,
            "session_id": session_id,
            "priority": 1
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "http://localhost:8000/api/llm/message",
                json=message
            )
            print(f"✉️  Sent result to {to_llm}")

    async def delegate_to_peer(self, task: str, context: Dict[str, Any], to_llm: str):
        """Delegate a task to another LLM instance"""
        import httpx
        import uuid

        session_id = str(uuid.uuid4())

        message = {
            "from_llm": self.instance_name,
            "to_llm": to_llm,
            "task": task,
            "context": context,
            "session_id": session_id,
            "priority": 1
        }

        async with httpx.AsyncClient() as client:
            await client.post(
                "http://localhost:8000/api/llm/message",
                json=message
            )
            print(f"📤 Delegated '{task}' to {to_llm}")

    async def run(self):
        """Main run loop"""
        await self.connect()

        # Start heartbeat and listening tasks concurrently
        await asyncio.gather(
            self.send_heartbeat(),
            self.listen_for_tasks()
        )

    async def shutdown(self):
        """Clean shutdown"""
        self.running = False
        if self.websocket:
            await self.websocket.close()
        if self.redis_client:
            await self.redis_client.close()
        print(f"👋 {self.instance_name} shut down")


async def main():
    """Entry point"""
    coordinator = LLMCoordinator(INSTANCE_NAME)

    try:
        await coordinator.run()
    except KeyboardInterrupt:
        print("\n⚠️  Shutdown signal received")
        await coordinator.shutdown()
    except Exception as e:
        print(f"❌ Error: {e}")
        await coordinator.shutdown()


if __name__ == "__main__":
    print(f"""
    ╔══════════════════════════════════════════╗
    ║   Antimony Labs - LLM Coordinator        ║
    ║   Instance: {INSTANCE_NAME:^28} ║
    ╚══════════════════════════════════════════╝
    """)

    asyncio.run(main())
