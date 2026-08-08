import { defineStore } from 'pinia';
import api from '@/services/api';

export const useAuthStore = defineStore('auth', {
    state: () => ({
        token: localStorage.getItem('auth_token') || null,
        user: JSON.parse(localStorage.getItem('auth_user') || 'null'),
    }),

    getters: {
        isAuthenticated: (state) => !!state.token,
        roleSlug: (state) => state.user?.role?.slug ?? null,
    },

    actions: {
        hasRole(...slugs) {
            return this.roleSlug !== null && slugs.includes(this.roleSlug);
        },

        async login(credentials) {
            const { data } = await api.post('/auth/login', credentials);
            this.setSession(data.data.token, data.data.user);
        },

        async fetchUser() {
            const { data } = await api.get('/auth/me');
            this.user = data.data;
            localStorage.setItem('auth_user', JSON.stringify(this.user));
        },

        async logout() {
            try {
                await api.post('/auth/logout');
            } catch {
                // ignore network errors on logout, clear session regardless
            } finally {
                this.clearSession();
            }
        },

        setSession(token, user) {
            this.token = token;
            this.user = user;
            localStorage.setItem('auth_token', token);
            localStorage.setItem('auth_user', JSON.stringify(user));
        },

        clearSession() {
            this.token = null;
            this.user = null;
            localStorage.removeItem('auth_token');
            localStorage.removeItem('auth_user');
        },
    },
});
