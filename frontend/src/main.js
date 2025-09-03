import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap/dist/js/bootstrap.bundle.min.js'
import { createApp } from 'vue'

import mainRouter from './router/router'

import App from './App.vue'

const app = createApp(App);

app.use(mainRouter);
app.mount('#app');