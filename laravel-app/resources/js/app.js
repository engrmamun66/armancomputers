import './bootstrap';
import '../css/app.css';
import './vendor/em-datetimepicker/em-datetimepicker-widget.min.js';

import { createApp } from 'vue';
import { createPinia } from 'pinia';
import moment from 'moment';
import App from './App.vue';
import router from './router';
import { useThemeStore } from './stores/theme';

const app = createApp(App);

app.provide('moment', moment);
app.use(createPinia());
app.use(router);
useThemeStore().init();
app.mount('#app');
