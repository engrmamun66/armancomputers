<script setup>
defineProps({
    label: { type: String, default: 'Loading…' },
    inline: { type: Boolean, default: false },
});
</script>

<template>
    <div :class="['flex items-center justify-center gap-2 text-slate-500', inline ? 'py-2' : 'py-12']">
        <svg class="animate-spin h-5 w-5 text-primary-600" viewBox="0 0 24 24" fill="none">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
        </svg>
        <span class="text-sm">{{ label }}</span>
    </div>
</template>
