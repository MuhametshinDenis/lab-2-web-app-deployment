export interface Todo {
  id: number
  title: string
  completed: boolean
  created_at: string
}

export interface CreateTodoPayload {
  title: string
  completed?: boolean
}

export interface UpdateTodoPayload {
  title: string
  completed: boolean
}
