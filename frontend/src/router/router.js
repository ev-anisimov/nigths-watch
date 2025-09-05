// src/router/index.js
import { createRouter, createWebHistory } from 'vue-router';
import MapPage from '../views/MapPage.vue';

const routes = [
  {
    path: '/',
    name: 'MapPage',
    component: MapPage,
  },
];

const router = createRouter({
  history: createWebHistory('/night/'),
  routes,
});

export default router;