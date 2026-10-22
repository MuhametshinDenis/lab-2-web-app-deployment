import { ref, computed, onMounted } from 'vue'

import { ApiError } from '@/shared/api'
import type { Todo } from '@/entities/todo'
import { getTodos, createTodo, deleteTodo, updateTodo } from '@/entities/todo'

export type TodoFilter = 'active' | 'all' | 'completed'

const getFriendlyError = (error: unknown) => {
  if (error instanceof ApiError) {
    if (error.status === 0) {
      return 'Сервер задач недоступен. Проверьте, запущен ли он, и попробуйте снова.'
    }

    return error.message
  }

  return 'Произошла непредвиденная ошибка. Попробуйте ещё раз.'
}

export const useTodoBoard = () => {
  const todos = ref<Todo[]>([])
  const filter = ref<TodoFilter>('all')
  const query = ref('')
  const newTodoTitle = ref('')
  const loadError = ref('')
  const mutationError = ref('')
  const isLoading = ref(true)
  const isCreating = ref(false)
  const pendingIds = ref(new Set<number>())

  const activeCount = computed(
    () => todos.value.filter(todo => !todo.completed).length,
  )
  const completedCount = computed(
    () => todos.value.filter(todo => todo.completed).length,
  )
  const progress = computed(() => {
    if (todos.value.length === 0) {
      return 0
    }

    return Math.round((completedCount.value / todos.value.length) * 100)
  })
  const filteredTodos = computed(() => {
    const normalizedQuery = query.value.trim().toLocaleLowerCase('ru-RU')

    return todos.value.filter(todo => {
      const matchesFilter =
        filter.value === 'all' ||
        (filter.value === 'active' && !todo.completed) ||
        (filter.value === 'completed' && todo.completed)
      const matchesQuery =
        !normalizedQuery ||
        todo.title.toLocaleLowerCase('ru-RU').includes(normalizedQuery)

      return matchesFilter && matchesQuery
    })
  })

  const replaceTodo = (updatedTodo: Todo) => {
    todos.value = todos.value.map(todo =>
      todo.id === updatedTodo.id ? updatedTodo : todo,
    )
  }

  const setPending = (id: number, value: boolean) => {
    const nextPendingIds = new Set(pendingIds.value)

    if (value) {
      nextPendingIds.add(id)
    } else {
      nextPendingIds.delete(id)
    }

    pendingIds.value = nextPendingIds
  }

  const loadTodos = async () => {
    isLoading.value = true
    loadError.value = ''

    try {
      todos.value = await getTodos()
    } catch (error) {
      loadError.value = getFriendlyError(error)
    } finally {
      isLoading.value = false
    }
  }

  const addTodo = async () => {
    const title = newTodoTitle.value.trim()

    if (!title || title.length > 200 || isCreating.value) {
      return
    }

    isCreating.value = true
    mutationError.value = ''

    try {
      const todo = await createTodo({ title })
      todos.value = [...todos.value, todo]
      newTodoTitle.value = ''
      filter.value = 'all'
    } catch (error) {
      mutationError.value = getFriendlyError(error)
    } finally {
      isCreating.value = false
    }
  }

  const toggleTodo = async (todo: Todo) => {
    setPending(todo.id, true)
    mutationError.value = ''

    try {
      replaceTodo(
        await updateTodo(todo.id, {
          title: todo.title,
          completed: !todo.completed,
        }),
      )
    } catch (error) {
      mutationError.value = getFriendlyError(error)
    } finally {
      setPending(todo.id, false)
    }
  }

  const renameTodo = async (todo: Todo, title: string) => {
    setPending(todo.id, true)
    mutationError.value = ''

    try {
      replaceTodo(
        await updateTodo(todo.id, { title, completed: todo.completed }),
      )
    } catch (error) {
      mutationError.value = getFriendlyError(error)
    } finally {
      setPending(todo.id, false)
    }
  }

  const removeTodo = async (todo: Todo) => {
    setPending(todo.id, true)
    mutationError.value = ''

    try {
      await deleteTodo(todo.id)
      todos.value = todos.value.filter(item => item.id !== todo.id)
    } catch (error) {
      mutationError.value = getFriendlyError(error)
    } finally {
      setPending(todo.id, false)
    }
  }

  onMounted(loadTodos)

  return {
    query,
    todos,
    filter,
    addTodo,
    progress,
    isLoading,
    loadError,
    loadTodos,
    isCreating,
    pendingIds,
    removeTodo,
    renameTodo,
    toggleTodo,
    activeCount,
    newTodoTitle,
    filteredTodos,
    mutationError,
    completedCount,
  }
}
