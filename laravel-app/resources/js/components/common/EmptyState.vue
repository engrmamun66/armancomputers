<script setup>
defineProps({
    title: { type: String, default: 'No records found.' },
    message: { type: String, default: '' },
    showClear: { type: Boolean, default: false },
});

defineEmits(['clear']);
</script>

<template>
    <div class="flex flex-col items-center justify-center text-center py-16 px-4">
        <svg class="h-12 w-12 text-slate-300 mb-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9h16.5M3.75 15h16.5M5.25 5.25h13.5a1.5 1.5 0 011.5 1.5v10.5a1.5 1.5 0 01-1.5 1.5H5.25a1.5 1.5 0 01-1.5-1.5V6.75a1.5 1.5 0 011.5-1.5z" />
        </svg>
        <p class="text-sm font-medium text-slate-700">{{ title }}</p>
        <p v-if="message" class="text-sm text-slate-500 mt-1">{{ message }}</p>
        <button
            v-if="showClear"
            type="button"
            class="mt-4 text-sm font-medium text-primary-600 hover:text-primary-700"
            @click="$emit('clear')"
        >
            Clear Filters
        </button>
    </div>
</template>
