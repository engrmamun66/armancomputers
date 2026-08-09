<script setup>
import { ref } from 'vue';
import { useThemeStore } from '@/stores/theme';
import Icon from '@/components/common/Icon.vue';

const theme = useThemeStore();
const open = ref(false);

const OPTIONS = [
    { value: 'light', label: 'Light', icon: 'sun' },
    { value: 'dark', label: 'Dark', icon: 'moon' },
    { value: 'auto', label: 'Auto', icon: 'desktop' },
];

function select(mode) {
    theme.setMode(mode);
    open.value = false;
}
</script>

<template>
    <div class="relative">
        <button
            type="button"
            class="h-9 w-9 flex items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-700"
            :aria-label="`Theme: ${theme.mode}`"
            @click="open = !open"
        >
            <Icon :name="OPTIONS.find((o) => o.value === theme.mode)?.icon" class="h-5 w-5" />
        </button>

        <div
            v-if="open"
            class="absolute right-0 mt-2 w-36 bg-white rounded-md shadow-lg border border-slate-200 py-1 text-sm z-30"
            @click="open = false"
        >
            <button
                v-for="option in OPTIONS"
                :key="option.value"
                type="button"
                class="w-full flex items-center gap-2 px-3 py-2 text-left hover:bg-slate-50"
                :class="theme.mode === option.value ? 'text-primary-700 font-medium' : 'text-slate-700'"
                @click="select(option.value)"
            >
                <Icon :name="option.icon" class="h-4 w-4" />
                {{ option.label }}
                <Icon v-if="theme.mode === option.value" name="check" class="h-4 w-4 ml-auto text-primary-600" />
            </button>
        </div>
    </div>
</template>
