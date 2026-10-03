import os, sqlite3, hashlib, secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import httpx
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from passlib.context import CryptContext
from pydantic import BaseModel
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Nexus AI"
    SECRET_KEY: str = "dev-secret-change-me"
    DATABASE_URL: str = "sqlite:///./nexus.db"
    AI_PROVIDER: str = "demo"
    AI_BASE_URL: str = ""
    AI_API_KEY: str = ""
    AI_MODEL: str = ""
    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_MB: int = 20

    class Config:
        env_file = ".env"

s = Settings()
Path(s.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
db_path = s.DATABASE_URL.replace("sqlite:///", "")
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer = HTTPBearer()
app = FastAPI(title=s.APP_NAME, version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

def db():
    c = sqlite3.connect(db_path)
    c.row_factory = sqlite3.Row
    return c

with db() as c:
    c.executescript("""
    CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, email TEXT UNIQUE NOT NULL, password TEXT NOT NULL, created_at TEXT);
    CREATE TABLE IF NOT EXISTS chats(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, title TEXT NOT NULL, created_at TEXT);
    CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY, chat_id INTEGER NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT);
    CREATE TABLE IF NOT EXISTS projects(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, name TEXT NOT NULL, description TEXT, created_at TEXT);
    CREATE TABLE IF NOT EXISTS agents(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, name TEXT NOT NULL, prompt TEXT NOT NULL, created_at TEXT);
    CREATE TABLE IF NOT EXISTS files(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, name TEXT NOT NULL, path TEXT NOT NULL, size INTEGER, created_at TEXT);
    """)

def token(uid: int):
    return jwt.encode({"sub": str(uid), "exp": datetime.now(timezone.utc)+timedelta(days=7)},
                      s.SECRET_KEY, algorithm="HS256")

def user_id(creds: HTTPAuthorizationCredentials = Depends(bearer)):
    try:
        return int(jwt.decode(creds.credentials, s.SECRET_KEY, algorithms=["HS256"])["sub"])
    except (JWTError, ValueError, KeyError):
        raise HTTPException(401, "Invalid or expired token")

class Auth(BaseModel):
    email: str
    password: str

class ChatIn(BaseModel):
    message: str
    model: str = "auto"

class CreateChat(BaseModel):
    title: str = "New Chat"

class ProjectIn(BaseModel):
    name: str
    description: str = ""

class AgentIn(BaseModel):
    name: str
    prompt: str

def demo_reply(msg: str):
    return ("Demo AI is active. Your message was received:\n\n" + msg +
            "\n\nConnect a real AI provider in backend/.env to generate model responses.")

async def ai_reply(msg: str, model: str):
    if s.AI_PROVIDER == "openai_compatible" and s.AI_BASE_URL and s.AI_API_KEY:
        url = s.AI_BASE_URL.rstrip("/") + "/chat/completions"
        payload = {"model": s.AI_MODEL or model, "messages":[{"role":"user","content":msg}]}
        headers = {"Authorization": f"Bearer {s.AI_API_KEY}"}
        async with httpx.AsyncClient(timeout=90) as x:
            r = await x.post(url, json=payload, headers=headers)
            r.raise_for_status()
            return r.json()["choices"][0]["message"]["content"]
    return demo_reply(msg)

@app.get("/health")
def health(): return {"ok": True, "app": s.APP_NAME}

@app.post("/auth/register")
def register(a: Auth):
    if len(a.password) < 6: raise HTTPException(400, "Password must be at least 6 characters")
    try:
        with db() as c:
            cur = c.execute("INSERT INTO users(email,password,created_at) VALUES(?,?,?)",
                            (a.email.lower().strip(), pwd.hash(a.password), datetime.now(timezone.utc).isoformat()))
            return {"token": token(cur.lastrowid), "email": a.email.lower().strip()}
    except sqlite3.IntegrityError:
        raise HTTPException(409, "Email already registered")

@app.post("/auth/login")
def login(a: Auth):
    with db() as c: u = c.execute("SELECT * FROM users WHERE email=?", (a.email.lower().strip(),)).fetchone()
    if not u or not pwd.verify(a.password, u["password"]): raise HTTPException(401, "Invalid credentials")
    return {"token": token(u["id"]), "email": u["email"]}

@app.get("/me")
def me(uid=Depends(user_id)):
    with db() as c: u=c.execute("SELECT id,email,created_at FROM users WHERE id=?", (uid,)).fetchone()
    return dict(u)

@app.post("/chats")
def create_chat(x: CreateChat, uid=Depends(user_id)):
    with db() as c:
        cur=c.execute("INSERT INTO chats(user_id,title,created_at) VALUES(?,?,?)",
                      (uid,x.title,datetime.now(timezone.utc).isoformat()))
        return {"id":cur.lastrowid,"title":x.title}

@app.get("/chats")
def chats(uid=Depends(user_id)):
    with db() as c: rows=c.execute("SELECT * FROM chats WHERE user_id=? ORDER BY id DESC",(uid,)).fetchall()
    return [dict(x) for x in rows]

@app.get("/chats/{cid}")
def chat(cid:int, uid=Depends(user_id)):
    with db() as c:
        q=c.execute("SELECT * FROM chats WHERE id=? AND user_id=?",(cid,uid)).fetchone()
        if not q: raise HTTPException(404,"Chat not found")
        m=c.execute("SELECT role,content,created_at FROM messages WHERE chat_id=? ORDER BY id",(cid,)).fetchall()
    return {"chat":dict(q),"messages":[dict(x) for x in m]}

@app.post("/chats/{cid}/messages")
async def send(cid:int, x:ChatIn, uid=Depends(user_id)):
    with db() as c:
        q=c.execute("SELECT id FROM chats WHERE id=? AND user_id=?",(cid,uid)).fetchone()
        if not q: raise HTTPException(404,"Chat not found")
        now=datetime.now(timezone.utc).isoformat()
        c.execute("INSERT INTO messages(chat_id,role,content,created_at) VALUES(?,?,?,?)",(cid,"user",x.message,now))
    reply=await ai_reply(x.message,x.model)
    with db() as c:
        c.execute("INSERT INTO messages(chat_id,role,content,created_at) VALUES(?,?,?,?)",(cid,"assistant",reply,datetime.now(timezone.utc).isoformat()))
    return {"reply":reply,"model":x.model}

@app.post("/projects")
def project(x:ProjectIn, uid=Depends(user_id)):
    with db() as c:
        cur=c.execute("INSERT INTO projects(user_id,name,description,created_at) VALUES(?,?,?,?)",
                      (uid,x.name,x.description,datetime.now(timezone.utc).isoformat()))
        return {"id":cur.lastrowid,"name":x.name,"description":x.description}

@app.get("/projects")
def projects(uid=Depends(user_id)):
    with db() as c: rows=c.execute("SELECT * FROM projects WHERE user_id=? ORDER BY id DESC",(uid,)).fetchall()
    return [dict(x) for x in rows]

@app.post("/agents")
def agent(x:AgentIn, uid=Depends(user_id)):
    with db() as c:
        cur=c.execute("INSERT INTO agents(user_id,name,prompt,created_at) VALUES(?,?,?,?)",
                      (uid,x.name,x.prompt,datetime.now(timezone.utc).isoformat()))
        return {"id":cur.lastrowid,"name":x.name,"prompt":x.prompt}

@app.get("/agents")
def agents(uid=Depends(user_id)):
    with db() as c: rows=c.execute("SELECT * FROM agents WHERE user_id=? ORDER BY id DESC",(uid,)).fetchall()
    return [dict(x) for x in rows]

@app.post("/files")
async def upload(file:UploadFile=File(...), uid=Depends(user_id)):
    data=await file.read()
    if len(data)>s.MAX_UPLOAD_MB*1024*1024: raise HTTPException(413,"File too large")
    safe=hashlib.sha256((str(uid)+secrets.token_hex(8)).encode()).hexdigest()+"_"+Path(file.filename or "file").name
    path=Path(s.UPLOAD_DIR)/safe
    path.write_bytes(data)
    with db() as c:
        cur=c.execute("INSERT INTO files(user_id,name,path,size,created_at) VALUES(?,?,?,?,?)",
                      (uid,file.filename or "file",str(path),len(data),datetime.now(timezone.utc).isoformat()))
    return {"id":cur.lastrowid,"name":file.filename,"size":len(data)}

@app.get("/files")
def files(uid=Depends(user_id)):
    with db() as c: rows=c.execute("SELECT id,name,size,created_at FROM files WHERE user_id=? ORDER BY id DESC",(uid,)).fetchall()
    return [dict(x) for x in rows]

@app.post("/research")
async def research(x:ChatIn, uid=Depends(user_id)):
    # Safe provider abstraction. A real search connector can be plugged in here.
    return {"query":x.message,"summary":await ai_reply("Research request: "+x.message,x.model),"sources":[]}

@app.post("/images")
async def images(x:ChatIn, uid=Depends(user_id)):
    return {"prompt":x.message,"status":"provider_required","message":"Connect an image provider on the backend to generate images."}

@app.get("/usage")
def usage(uid=Depends(user_id)):
    with db() as c:
        chats=c.execute("SELECT COUNT(*) n FROM chats WHERE user_id=?",(uid,)).fetchone()["n"]
        msgs=c.execute("SELECT COUNT(*) n FROM messages m JOIN chats c ON c.id=m.chat_id WHERE c.user_id=?",(uid,)).fetchone()["n"]
        fs=c.execute("SELECT COUNT(*) n FROM files WHERE user_id=?",(uid,)).fetchone()["n"]
    return {"chats":chats,"messages":msgs,"files":fs}
