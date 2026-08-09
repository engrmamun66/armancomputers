import { defineStore } from 'pinia';
import { applyChartTheme } from '@/utils/chartSetup';

const STORAGE_KEY = 'theme-mode';

export const useThemeStore = defineStore('theme', {
    state: () => ({
        mode: localStorage.getItem(STORAGE_KEY) || 'auto',
        systemPrefersDark: window.matchMedia('(prefers-color-scheme: dark)').matches,
    }),

    getters: {
        isDark: (state) => state.mode === 'dark' || (state.mode === 'auto' && state.systemPrefersDark),
    },

    actions: {
        setMode(mode) {
            this.mode = mode;
            localStorage.setItem(STORAGE_KEY, mode);
            this.apply();
        },

        apply() {
            document.documentElement.style.colorScheme = this.mode === 'auto' ? 'light dark' : this.mode;
            applyChartTheme(this.isDark);
        },

        init() {
            this.apply();
            window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (event) => {
                this.systemPrefersDark = event.matches;
                if (this.mode === 'auto') applyChartTheme(this.isDark);
            });
        },
    },
});
