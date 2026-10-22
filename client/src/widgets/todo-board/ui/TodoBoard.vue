<script setup lang="ts">
import { TodoItem } from '@/features/manage-todo'
import { CreateTodoForm } from '@/features/create-todo'

import { useTodoBoard } from '../model/useTodoBoard'
import type { TodoFilter } from '../model/useTodoBoard'

const {
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
} = useTodoBoard()

const filters: { label: string; value: TodoFilter }[] = [
  { label: 'Все', value: 'all' },
  { value: 'active', label: 'В работе' },
  { label: 'Готово', value: 'completed' },
]
</script>

<template>
  <section class="todo-board">
    <header class="todo-board__header">
      <div>
        <p class="todo-board__eyebrow">
          <span />
          Список дел
        </p>
        <h1>Ваши задачи</h1>
        <p class="todo-board__subtitle">
          Маленькие шаги ведут к большим результатам.
        </p>
      </div>

      <div class="todo-board__date-mark" aria-hidden="true">
        <svg viewBox="0 0 24 24">
          <path
            d="M7 3v3m10-3v3M4 9h16M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1Z"
          />
        </svg>
      </div>
    </header>

    <CreateTodoForm
      v-model="newTodoTitle"
      :is-submitting="isCreating"
      @submit="addTodo"
    />

    <div v-if="mutationError" class="todo-board__notice" role="alert">
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M12 8v5m0 3.5v.5M4.2 19h15.6L12 4 4.2 19Z" />
      </svg>
      <span>{{ mutationError }}</span>
      <button
        type="button"
        aria-label="Закрыть сообщение"
        @click="mutationError = ''"
      >
        ×
      </button>
    </div>

    <template v-if="!loadError">
      <div class="todo-board__overview">
        <div class="todo-board__progress-copy">
          <span>Прогресс</span>
          <strong>{{ progress }}%</strong>
        </div>
        <div
          class="todo-board__progress-track"
          role="progressbar"
          aria-label="Выполнено задач"
          :aria-valuenow="progress"
          aria-valuemin="0"
          aria-valuemax="100"
        >
          <span :style="{ width: `${progress}%` }" />
        </div>
        <p>
          <strong>{{ completedCount }}</strong> выполнено ·
          <strong>{{ activeCount }}</strong> осталось
        </p>
      </div>

      <div class="todo-board__toolbar">
        <div class="todo-board__filters" aria-label="Фильтр задач">
          <button
            v-for="item in filters"
            :key="item.value"
            type="button"
            :class="{ 'todo-board__filter--active': filter === item.value }"
            @click="filter = item.value"
          >
            {{ item.label }}
            <span v-if="item.value === 'all'">{{ todos.length }}</span>
            <span v-else-if="item.value === 'active'">{{ activeCount }}</span>
            <span v-else>{{ completedCount }}</span>
          </button>
        </div>

        <label class="todo-board__search">
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <circle cx="11" cy="11" r="6" />
            <path d="m16 16 4 4" />
          </svg>
          <input v-model="query" type="search" placeholder="Найти" />
        </label>
      </div>

      <div
        v-if="isLoading"
        class="todo-board__skeletons"
        aria-label="Загрузка задач"
      >
        <div v-for="item in 3" :key="item" class="todo-board__skeleton">
          <span />
          <div>
            <i />
            <i />
          </div>
        </div>
      </div>

      <TransitionGroup
        v-else-if="filteredTodos.length"
        tag="div"
        name="todo-list"
        class="todo-board__list"
      >
        <TodoItem
          v-for="todo in filteredTodos"
          :key="todo.id"
          :todo="todo"
          :is-pending="pendingIds.has(todo.id)"
          @toggle="toggleTodo"
          @rename="renameTodo"
          @remove="removeTodo"
        />
      </TransitionGroup>

      <div v-else class="todo-board__empty">
        <div class="todo-board__empty-icon">
          <svg aria-hidden="true" viewBox="0 0 32 32">
            <path d="M9 6h14v20H9zM13 11h6m-6 5h6m-6 5h4" />
          </svg>
        </div>
        <h2 v-if="todos.length === 0">Здесь пока спокойно</h2>
        <h2 v-else>Ничего не найдено</h2>
        <p v-if="todos.length === 0">
          Добавьте первую задачу.
        </p>
        <p v-else>Попробуйте изменить фильтр или поисковый запрос.</p>
      </div>
    </template>

    <div v-else class="todo-board__connection-error" role="alert">
      <div class="todo-board__connection-icon">
        <svg aria-hidden="true" viewBox="0 0 32 32">
          <path
            d="M8 22a10 10 0 0 1 16 0M12 18a6 6 0 0 1 8 0M15.5 25h1M5 5l22 22"
          />
        </svg>
      </div>
      <h2>Нет связи с сервером</h2>
      <p>{{ loadError }}</p>
      <button type="button" :disabled="isLoading" @click="loadTodos">
        <span v-if="isLoading" class="todo-board__retry-spinner" />
        <span v-else>Попробовать снова</span>
      </button>
    </div>

    <footer class="todo-board__footer">
      <span />
      Твои дела — твоё дело © Jason Statham
      <span />
    </footer>
  </section>
</template>
