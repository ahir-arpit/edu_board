import asyncio
import json
import logging
import uuid
from typing import Dict, Set, List, Optional
from fastapi import WebSocket
from redis.asyncio import Redis
from app.core.config import settings

logger = logging.getLogger("smartboard_backend")

class ConnectionManager:
    def __init__(self):
        # Local state (WebSocket connection objects can't be shared across instances)
        # Maps session_code -> Set of active WebSockets
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # Maps session_code -> asyncio Task for Redis Subscription
        self.redis_tasks: Dict[str, asyncio.Task] = {}
        
        # Local Fallback state (used only if Redis is unavailable)
        self.session_strokes_fallback: Dict[str, List[dict]] = {}
        self.websocket_users_fallback: Dict[WebSocket, dict] = {}

        # Redis Connection Setup
        self.redis_client: Optional[Redis] = None
        self.redis_available = False
        self.redis_connection_checked = False
        
        self._init_redis_client()

    def _init_redis_client(self):
        try:
            self.redis_client = Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                db=0,
                decode_responses=True
            )
        except Exception as e:
            logger.warning(f"Failed to initialize Redis client: {e}. Falling back to in-memory mode.")
            self.redis_available = False
            self.redis_connection_checked = True

    async def _check_redis_connection(self):
        self.redis_connection_checked = True
        if not self.redis_client:
            return
        try:
            await self.redis_client.ping()
            self.redis_available = True
            logger.info("Successfully connected to Redis for scaling/caching.")
        except Exception as e:
            logger.warning(f"Could not connect to Redis ({e}). Active session sync will be local only.")
            self.redis_available = False

    async def connect(self, websocket: WebSocket, session_code: str):
        await websocket.accept()
        # Assign a unique connection ID to this WebSocket instance
        websocket.connection_id = str(uuid.uuid4())
        
        # Verify Redis connection on first websocket handshake
        if self.redis_client and not self.redis_connection_checked:
            await self._check_redis_connection()

        if session_code not in self.active_connections:
            self.active_connections[session_code] = set()
            
        self.active_connections[session_code].add(websocket)
        
        # Start Redis subscriber task for this session if Redis is available and not already subscribed
        if self.redis_available and session_code not in self.redis_tasks:
            self.redis_tasks[session_code] = asyncio.create_task(
                self._listen_redis_channel(session_code)
            )

    async def _listen_redis_channel(self, session_code: str):
        """
        Subscribes to session's Redis channel and listens for pub/sub events.
        """
        pubsub = self.redis_client.pubsub()
        await pubsub.subscribe(f"session:{session_code}")
        logger.info(f"Subscribed to Redis channel: session:{session_code}")
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    try:
                        data = json.loads(message["data"])
                        sender_id = data.get("sender_id")
                        payload = data.get("payload")
                        
                        # Broadcast message to local web sockets, excluding the sender
                        if session_code in self.active_connections:
                            local_websockets = self.active_connections[session_code]
                            tasks = []
                            for ws in local_websockets:
                                if getattr(ws, "connection_id", None) != sender_id:
                                    tasks.append(ws.send_text(json.dumps(payload)))
                            if tasks:
                                await asyncio.gather(*tasks, return_exceptions=True)
                    except Exception as e:
                        logger.error(f"Error handling Redis pubsub message for session {session_code}: {e}")
        except asyncio.CancelledError:
            logger.info(f"Redis listener task cancelled for session: {session_code}")
        except Exception as e:
            logger.error(f"Error in Redis subscriber for session {session_code}: {e}")
        finally:
            await pubsub.unsubscribe(f"session:{session_code}")
            await pubsub.close()

    async def register_user(self, websocket: WebSocket, session_code: str, name: str, role: str):
        connection_id = getattr(websocket, "connection_id", None)
        user_meta = {
            "name": name,
            "role": role,
            "connection_id": connection_id,
            "session_code": session_code
        }
        
        if self.redis_available:
            try:
                users_key = f"session_users:{session_code}"
                # Push user meta to Redis session users list
                await self.redis_client.rpush(users_key, json.dumps(user_meta))
                await self.broadcast_users_list(session_code)
                return
            except Exception as e:
                logger.error(f"Error registering user in Redis: {e}")
                
        # Local fallback
        self.websocket_users_fallback[websocket] = user_meta
        await self.broadcast_users_list(session_code)

    async def disconnect(self, websocket: WebSocket, session_code: str):
        if session_code in self.active_connections:
            self.active_connections[session_code].discard(websocket)
            if not self.active_connections[session_code]:
                del self.active_connections[session_code]
                # Cancel Redis subscriber task if no local connections are active
                task = self.redis_tasks.pop(session_code, None)
                if task:
                    task.cancel()

        # Remove from local or Redis users list
        connection_id = getattr(websocket, "connection_id", None)
        if connection_id:
            if self.redis_available:
                try:
                    users_key = f"session_users:{session_code}"
                    users_data = await self.redis_client.lrange(users_key, 0, -1)
                    for item in users_data:
                        parsed = json.loads(item)
                        if parsed.get("connection_id") == connection_id:
                            await self.redis_client.lrem(users_key, 1, item)
                            break
                    await self.broadcast_users_list(session_code)
                    return
                except Exception as e:
                    logger.error(f"Error removing user from Redis: {e}")
            
            # Local fallback
            if websocket in self.websocket_users_fallback:
                del self.websocket_users_fallback[websocket]
                await self.broadcast_users_list(session_code)

    async def get_session_users(self, session_code: str) -> List[dict]:
        if self.redis_available:
            try:
                users_key = f"session_users:{session_code}"
                users_data = await self.redis_client.lrange(users_key, 0, -1)
                users = []
                for item in users_data:
                    parsed = json.loads(item)
                    users.append({
                        "name": parsed["name"],
                        "role": parsed["role"]
                    })
                return users
            except Exception as e:
                logger.error(f"Error fetching users from Redis: {e}")
                
        # Local fallback
        users = []
        for ws, info in self.websocket_users_fallback.items():
            if info["session_code"] == session_code:
                users.append({
                    "name": info["name"],
                    "role": info["role"]
                })
        return users

    async def broadcast_users_list(self, session_code: str):
        users_list = await self.get_session_users(session_code)
        message = {
            "event": "participants_list",
            "session_code": session_code,
            "data": users_list
        }
        if self.redis_available:
            await self.publish_to_session(message, session_code)
        else:
            await self.broadcast_to_session(message, session_code)

    async def broadcast_to_session(self, message: dict, session_code: str, exclude_websocket: WebSocket = None):
        """
        Local broadcast (used for fallbacks or direct publishing).
        Sends message to all WebSocket connections on this server instance.
        """
        if session_code not in self.active_connections:
            return

        payload = json.dumps(message)
        dead_connections = set()
        
        tasks = []
        websockets_to_send = []
        for connection in self.active_connections[session_code]:
            if connection == exclude_websocket:
                continue
            websockets_to_send.append(connection)
            tasks.append(connection.send_text(payload))
            
        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    dead_connections.add(websockets_to_send[i])

        for connection in dead_connections:
            await self.disconnect(connection, session_code)

    async def publish_to_session(self, message: dict, session_code: str, exclude_websocket: WebSocket = None):
        """
        Publishes a message to the Redis pub/sub channel.
        If Redis is not available, falls back to direct local broadcast.
        """
        if self.redis_available:
            sender_id = getattr(exclude_websocket, "connection_id", None)
            pub_data = {
                "sender_id": sender_id,
                "payload": message
            }
            try:
                await self.redis_client.publish(f"session:{session_code}", json.dumps(pub_data))
                return
            except Exception as e:
                logger.error(f"Failed to publish to Redis: {e}")
        
        await self.broadcast_to_session(message, session_code, exclude_websocket=exclude_websocket)

    async def save_stroke_memory(self, session_code: str, stroke: dict):
        if self.redis_available:
            strokes_key = f"session_strokes:{session_code}"
            try:
                if stroke.get("event") == "canvas_action" and stroke.get("data", {}).get("action") == "clear":
                    await self.redis_client.delete(strokes_key)
                elif stroke.get("event") == "canvas_action" and stroke.get("data", {}).get("action") == "undo":
                    await self.redis_client.rpop(strokes_key)
                elif stroke.get("event") in ("draw_stroke", "draw_shape"):
                    await self.redis_client.rpush(strokes_key, json.dumps(stroke.get("data")))
                return
            except Exception as e:
                logger.error(f"Error saving stroke memory in Redis: {e}")
                
        # Local fallback
        if session_code not in self.session_strokes_fallback:
            self.session_strokes_fallback[session_code] = []
            
        if stroke.get("event") == "canvas_action" and stroke.get("data", {}).get("action") == "clear":
            self.session_strokes_fallback[session_code] = []
        elif stroke.get("event") == "canvas_action" and stroke.get("data", {}).get("action") == "undo":
            if self.session_strokes_fallback[session_code]:
                self.session_strokes_fallback[session_code].pop()
        elif stroke.get("event") in ("draw_stroke", "draw_shape"):
            self.session_strokes_fallback[session_code].append(stroke.get("data"))

    async def get_session_strokes(self, session_code: str) -> List[dict]:
        if self.redis_available:
            strokes_key = f"session_strokes:{session_code}"
            try:
                strokes_data = await self.redis_client.lrange(strokes_key, 0, -1)
                return [json.loads(item) for item in strokes_data]
            except Exception as e:
                logger.error(f"Error fetching strokes from Redis: {e}")
                
        return self.session_strokes_fallback.get(session_code, [])

manager = ConnectionManager()
