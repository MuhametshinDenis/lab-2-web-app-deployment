<script setup lang="ts">
import { ref, watch, nextTick } from 'vue'

import type { Todo } from '@/entities/todo'

const props = defineProps<{
  isPending: boolean
  todo: Todo
}>()

const emit = defineEmits<{
  remove: [todo: Todo]
  rename: [todo: Todo, title: string]
  toggle: [todo: Todo]
}>()

const editInput = ref<HTMLInputElement | null>(null)
const editTitle = ref(props.todo.title)
const editError = ref('')
const isEditing = ref(false)

watch(
  () => props.todo.title,
  value => {
    if (!isEditing.value) {
      editTitle.value = value
    }
  },
)

const formatDate = (value: string) => {
  const date = new Date(value)

  if (Number.isNaN(date.getTime())) {
    return 'дата не указана'
  }

  return new Intl.DateTimeFormat('ru-RU', {
    day: 'numeric',
    month: 'short',
  }).format(date)
}

const startEditing = async () => {
  if (props.isPending) {
    return
  }

  editTitle.value = props.todo.title
  editError.value = ''
  isEditing.value = true
  await nextTick()
  editInput.value?.focus()
  editInput.value?.select()
}

const cancelEditing = () => {
  editTitle.value = props.todo.title
  editError.value = ''
  isEditing.value = false
}

const saveTitle = () => {
  const title = editTitle.value.trim()

  if (!title) {
    editError.value = 'Название не может быть пустым'
    return
  }

  if (title.length > 200) {
    editError.value = 'Максимум 200 символов'
    return
  }

  if (title !== props.todo.title) {
    emit('rename', props.todo, title)
  }

  isEditing.value = false
  editError.value = ''
}
</script>

<template>
  <article
    class="todo-item"
    :class="{
      'todo-item--completed': todo.completed,
      'todo-item--pending': isPending,
    }"
  >
    <label class="todo-item__check">
      <input
        class="todo-item__checkbox"
        type="checkbox"
        :checked="todo.completed"
        :disabled="isPending"
        :aria-label="
          todo.completed
            ? `Вернуть задачу «${todo.title}» в работу`
            : `Отметить задачу «${todo.title}» выполненной`
        "
        @click.prevent="emit('toggle', todo)"
      />
      <span class="todo-item__checkmark">
        <svg aria-hidden="true" viewBox="0 0 20 20">
          <path d="m5 10 3.2 3.2L15.5 6.8" />
        </svg>
      </span>
    </label>

    <div class="todo-item__content">
      <form v-if="isEditing" @submit.prevent="saveTitle">
        <input
          ref="editInput"
          v-model="editTitle"
          class="todo-item__edit-input"
          aria-label="Новое название задачи"
          :aria-invalid="Boolean(editError)"
          @keydown.esc.prevent="cancelEditing"
        />
        <p v-if="editError" class="todo-item__edit-error">
          {{ editError }}
        </p>
      </form>
      <template v-else>
        <button
          class="todo-item__title"
          type="button"
          :disabled="isPending"
          title="Изменить название"
          @click="startEditing"
        >
          {{ todo.title }}
        </button>
        <time class="todo-item__date" :datetime="todo.created_at">
          Добавлено {{ formatDate(todo.created_at) }}
        </time>
      </template>
    </div>

    <div v-if="isEditing" class="todo-item__actions">
      <button
        class="todo-item__action todo-item__action--save"
        type="button"
        aria-label="Сохранить название"
        @click="saveTitle"
      >
        <svg aria-hidden="true" viewBox="0 0 20 20">
          <path d="m4 10 3.5 3.5L16 5" />
        </svg>
      </button>
      <button
        class="todo-item__action"
        type="button"
        aria-label="Отменить редактирование"
        @click="cancelEditing"
      >
        <svg aria-hidden="true" viewBox="0 0 20 20">
          <path d="m5 5 10 10M15 5 5 15" />
        </svg>
      </button>
    </div>
    <button
      v-else
      class="todo-item__remove"
      type="button"
      :disabled="isPending"
      :aria-label="`Удалить задачу «${todo.title}»`"
      title="Удалить"
      @click="emit('remove', todo)"
    >
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M4 7h16M9 7V4h6v3m3 0-1 13H7L6 7m4 4v5m4-5v5" />
      </svg>
    </button>
  </article>
</template>
