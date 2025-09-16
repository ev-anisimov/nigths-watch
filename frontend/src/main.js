import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap/dist/js/bootstrap.bundle.min.js'
import { createApp } from 'vue'
import 'bootstrap';
import {createPinia} from "pinia";

import router from './router/router'

import App from './App.vue'

const app = createApp(App);
app.use(router);
app.use(createPinia());
app.mount('#app');