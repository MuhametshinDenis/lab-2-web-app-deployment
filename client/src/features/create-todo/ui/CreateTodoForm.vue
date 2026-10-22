<script setup lang="ts">
import { ref, computed } from 'vue'

const props = defineProps<{
  isSubmitting: boolean
  modelValue: string
}>()

const emit = defineEmits<{
  'submit': []
  'update:modelValue': [value: string]
}>()

const wasSubmitted = ref(false)

const normalizedTitle = computed(() => props.modelValue.trim())
const isEmpty = computed(() => normalizedTitle.value.length === 0)
const isTooLong = computed(() => normalizedTitle.value.length > 200)
const errorMessage = computed(() => {
  if (!wasSubmitted.value) {
    return ''
  }

  if (isEmpty.value) {
    return 'Введите название задачи'
  }

  if (isTooLong.value) {
    return 'Название не должно быть длиннее 200 символов'
  }

  return ''
})

const handleInput = (event: Event) => {
  const target = event.target as HTMLInputElement

  emit('update:modelValue', target.value)

  if (wasSubmitted.value) {
    wasSubmitted.value = false
  }
}

const handleSubmit = () => {
  wasSubmitted.value = true

  if (isEmpty.value || isTooLong.value || props.isSubmitting) {
    return
  }

  emit('submit')
  wasSubmitted.value = false
}
</script>

<template>
  <form class="create-todo" novalidate @submit.prevent="handleSubmit">
    <div class="create-todo__field">
      <svg class="create-todo__spark" aria-hidden="true" viewBox="0 0 24 24">
        <path d="M12 3v18M3 12h18" />
      </svg>
      <input
        :value="modelValue"
        class="create-todo__input"
        type="text"
        placeholder="Что нужно сделать?"
        aria-label="Название новой задачи"
        :aria-invalid="Boolean(errorMessage)"
        :disabled="isSubmitting"
        @input="handleInput"
      />
      <span
        v-if="modelValue.length > 160"
        class="create-todo__counter"
        :class="{ 'create-todo__counter--invalid': isTooLong }"
      >
        {{ modelValue.length }}/200
      </span>
      <button
        class="create-todo__button"
        type="submit"
        :disabled="isSubmitting || isEmpty || isTooLong"
      >
        <span v-if="isSubmitting" class="create-todo__spinner" />
        <span v-else>Добавить</span>
      </button>
    </div>
    <p v-if="errorMessage" class="create-todo__error" role="alert">
      {{ errorMessage }}
    </p>
  </form>
</template>
