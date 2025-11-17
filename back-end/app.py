from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2

app = FastAPI()

# ---------------------------
# CORS
# ---------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],     # permite qualquer origem
    allow_credentials=True,
    allow_methods=["*"],     # permite todos os métodos (GET, POST, etc)
    allow_headers=["*"],     # permite todos os headers
)

# ---------------------------
# Conexão ao PostgreSQL
# ---------------------------
def get_conn():
    return psycopg2.connect(
        host="localhost",
        database="todos",
        user="postgres",
        password="Pg@123"
    )

# ---------------------------
# Modelos
# ---------------------------
class TodoCreate(BaseModel):
    title: str
    description: str

# ---------------------------
# Endpoints
# ---------------------------

@app.get("/")
async def root():
    return {"message": "Hello World"}

# GET /todos
@app.get("/todos")
def get_todos():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, title, description FROM todos ORDER BY id;")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    todos = [{"id": r[0], "title": r[1], "description": r[2]} for r in rows]
    return todos

# GET /todos/{id}
@app.get("/todos/{id}")
def get_todo(id: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, title, description FROM todos WHERE id=%s;", (id,))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Todo não encontrado")

    return {"id": row[0], "title": row[1], "description": row[2]}

# POST /todos
@app.post("/todos")
def create_todo(todo: TodoCreate):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO todos (title, description) VALUES (%s, %s) RETURNING id;",
        (todo.title, todo.description)
    )
    new_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()

    return {"id": new_id, "title": todo.title, "description": todo.description}

# DELETE /todos/{id}
@app.delete("/todos/{id}")
def delete_todo(id: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM todos WHERE id=%s;", (id,))
    conn.commit()
    cur.close()
    conn.close()
