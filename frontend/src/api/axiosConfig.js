import axios from 'axios';
import {useAuthStore} from "@/stores/auth";
import { useNotificationStore } from '@/stores/notificationStore'


let routerInstance = null;

export function initApi(router) {
    routerInstance = router;
}
const api = axios.create({
    baseURL: '/auth/api',
    withCredentials: true, // Для передачи кук с авторизацией
    headers: {
        'Content-Type': 'application/json',
    }
});

api.interceptors.request.use((config) => {
  const authStore = useAuthStore();
  if (authStore.token) {
    config.headers.Authorization = `Bearer ${authStore.token}`;
  }
  return config;
});

api.interceptors.response.use(
    response => response,
    error => {
        // const router = useRouter();
        const authStore = useAuthStore();

        const notify = useNotificationStore()
        if (error.response) {
            const status = error.response.status;

            if (status === 401) {
                console.warn('Пользователь не авторизован. Редирект на логин.');
                authStore.logout();
                if (routerInstance) {
                    routerInstance.push('/login');
                } else {
                    console.warn('Router not initialized!');
                }
            }
            else if (status === 403) {
                console.warn('Нет прав доступа.');
                notify.addMessage('У вас нет прав доступа.','error', true, 10000);
            }
            else if (status >= 500) {
                console.error('Ошибка сервера. Попробуйте позже.');
                notify.addMessage('Ошибка сервера. Пожалуйста, попробуйте позже.','error', true, 10000);
            }
            return Promise.reject(error);

        }

        // Обязательно пробрасывай ошибку дальше, чтобы её можно было обработать локально при необходимости

    }
);
const apiNoneToken = axios.create({
    baseURL: '/auth/api',
    withCredentials: false, // Для передачи кук с авторизацией
    headers: {
        'Content-Type': 'application/json',
    }
});
export { apiNoneToken };
export default api;
