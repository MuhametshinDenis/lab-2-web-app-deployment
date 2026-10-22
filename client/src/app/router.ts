import { createRouter, createWebHistory } from 'vue-router'

import { MainPage } from '@/pages/main'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'main',
      component: MainPage,
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: { name: 'main' },
    },
  ],
})
