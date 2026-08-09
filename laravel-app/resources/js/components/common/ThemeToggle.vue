<script setup>
import { computed } from 'vue';
import { useThemeStore } from '@/stores/theme';
import Icon from '@/components/common/Icon.vue';

const theme = useThemeStore();

const CYCLE = ['light', 'dark', 'auto'];
const ICONS = { light: 'sun', dark: 'moon', auto: 'desktop' };

const icon = computed(() => ICONS[theme.mode]);

function cycle() {
    const next = CYCLE[(CYCLE.indexOf(theme.mode) + 1) % CYCLE.length];
    theme.setMode(next);
}
</script>

<template>
    <button
        type="button"
        class="h-9 w-9 flex items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-700"
        :aria-label="`Theme: ${theme.mode}`"
        @click="cycle"
    >
        <Icon :name="icon" class="h-5 w-5" />
    </button>
</template>
