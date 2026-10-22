import { request } from '@/shared/api'

import type {
  Todo,
  CreateTodoPayload,
  UpdateTodoPayload,
} from '../model/types.ts'

export const getTodos = () => request<Todo[]>('/todos')

export const createTodo = (payload: CreateTodoPayload) =>
  request<Todo>('/todos', {
    method: 'POST',
    body: JSON.stringify(payload),
  })

export const updateTodo = (id: number, payload: UpdateTodoPayload) =>
  request<Todo>(`/todos/${id}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  })

export const deleteTodo = (id: number) =>
  request<void>(`/todos/${id}`, { method: 'DELETE' })
