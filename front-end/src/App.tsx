import { useState, useEffect } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

import {
  Dialog,
  DialogTrigger,
  DialogClose,
  DialogContent,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogHeader,
} from "@/components/ui/dialog";

import {
  AlertDialog,
  AlertDialogTrigger,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogFooter,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogTitle,
  AlertDialogDescription,
} from "@/components/ui/alert-dialog";

import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

import { api } from "./services/api";

type Todo = {
  id: number;
  title: string;
  description: string;
};

function App() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [newTodo, setNewTodo] = useState({ title: "", description: "" });

  const [todoToDelete, setTodoToDelete] = useState<number | null>(null);

  // -----------------------------
  // BUSCAR TODOS AO CARREGAR
  // -----------------------------
  useEffect(() => {
    api.get("/todos").then((response) => {
      setTodos(response.data);
      console.log(response.data);
    });
  }, []);

  // -----------------------------
  // ADICIONAR NOVO TODO
  // -----------------------------
  function addNewTodo() {
    if (!newTodo.title.trim()) return;

    const payload = {
      title: newTodo.title,
      description: newTodo.description,
    };

    api.post("/todos", payload).then((response) => {
      // atualiza lista na tela
      setTodos((prev) => [...prev, response.data]);
    });

    setNewTodo({ title: "", description: "" });
  }

  // -----------------------------
  // DELETAR TODO
  // -----------------------------
  function deleteTodo(id: number) {
    api.delete(`/todos/${id}`).then(() => {
      setTodos((prev) => prev.filter((t) => t.id !== id));
    });

    setTodoToDelete(null);
  }

  return (
    <div className="p-6 max-w-3xl mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-center">Gerenciador de To-Dos</h1>

      {/* BOTÃO ADICIONAR */}
      <Dialog>
        <DialogTrigger asChild>
          <Button className="w-full">Adicionar To-Do</Button>
        </DialogTrigger>

        <DialogContent>
          <DialogHeader>
            <DialogTitle>Novo To-Do</DialogTitle>
            <DialogDescription>Preencha os campos abaixo.</DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <Input
              placeholder="Título"
              value={newTodo.title}
              onChange={(e) =>
                setNewTodo({ ...newTodo, title: e.target.value })
              }
            />

            <Input
              placeholder="Descrição"
              value={newTodo.description}
              onChange={(e) =>
                setNewTodo({ ...newTodo, description: e.target.value })
              }
            />
          </div>

          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Cancelar</Button>
            </DialogClose>

            <DialogClose asChild>
              <Button onClick={addNewTodo}>Salvar</Button>
            </DialogClose>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* TABELA DOS TODOS */}
      <Table>
        <TableCaption>Lista de tarefas criadas</TableCaption>

        <TableHeader>
          <TableRow>
            <TableHead>ID</TableHead>
            <TableHead>Título</TableHead>
            <TableHead>Descrição</TableHead>
            <TableHead className="text-right">Ações</TableHead>
          </TableRow>
        </TableHeader>

        <TableBody>
          {todos.map((todo) => (
            <TableRow key={todo.id}>
              <TableCell>{todo.id}</TableCell>
              <TableCell>{todo.title}</TableCell>
              <TableCell>{todo.description}</TableCell>

              <TableCell className="text-right space-x-2">
                {/* VISUALIZAR */}
                <Dialog>
                  <DialogTrigger asChild>
                    <Button variant="secondary">Visualizar</Button>
                  </DialogTrigger>

                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>{todo.title}</DialogTitle>
                      <DialogDescription>{todo.description}</DialogDescription>
                    </DialogHeader>
                  </DialogContent>
                </Dialog>

                {/* DELETAR */}
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button
                      variant="destructive"
                      onClick={() => setTodoToDelete(todo.id)}
                    >
                      Deletar
                    </Button>
                  </AlertDialogTrigger>

                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>Deseja deletar?</AlertDialogTitle>
                      <AlertDialogDescription>
                        Essa ação não pode ser desfeita.
                      </AlertDialogDescription>
                    </AlertDialogHeader>

                    <AlertDialogFooter>
                      <AlertDialogCancel>Cancelar</AlertDialogCancel>
                      <AlertDialogAction
                        onClick={() => {
                          if (todoToDelete !== null) {
                            deleteTodo(todoToDelete);
                          }
                        }}
                      >
                        Deletar
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>

        <TableFooter>
          <TableRow>
            <TableCell colSpan={3}>Total: {todos.length} tarefa(s)</TableCell>
          </TableRow>
        </TableFooter>
      </Table>
    </div>
  );
}

export default App;
