<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
    modelValue: { type: String, default: '' },
    placeholder: { type: String, default: 'Search…' },
    debounce: { type: Number, default: 350 },
});

const emit = defineEmits(['update:modelValue']);

const local = ref(props.modelValue);
let timer = null;

watch(
    () => props.modelValue,
    (value) => {
        if (value !== local.value) local.value = value;
    }
);

watch(local, (value) => {
    clearTimeout(timer);
    timer = setTimeout(() => emit('update:modelValue', value), props.debounce);
});
</script>

<template>
    <div class="relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="7" />
            <path stroke-linecap="round" d="M21 21l-4.35-4.35" />
        </svg>
        <input
            v-model="local"
            type="text"
            :placeholder="placeholder"
            class="w-full pl-9 pr-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
        />
    </div>
</template>
