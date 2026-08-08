<script setup>
import { computed } from 'vue';

const props = defineProps({
    status: { type: String, required: true },
});

const styles = {
    active: 'bg-emerald-100 text-emerald-700',
    inactive: 'bg-slate-100 text-slate-600',
    paid: 'bg-emerald-100 text-emerald-700',
    partial: 'bg-amber-100 text-amber-700',
    due: 'bg-rose-100 text-rose-700',
    'low-stock': 'bg-amber-100 text-amber-700',
    'out-of-stock': 'bg-rose-100 text-rose-700',
    pending: 'bg-amber-100 text-amber-700',
    cancelled: 'bg-slate-100 text-slate-500',
    completed: 'bg-emerald-100 text-emerald-700',
};

const slug = computed(() => (props.status || '').toString().toLowerCase().replace(/\s+/g, '-'));
const classes = computed(() => styles[slug.value] || 'bg-slate-100 text-slate-600');
const label = computed(() => (props.status || '').toString().replace(/(^|\s|-)\S/g, (c) => c.toUpperCase()).replace(/-/g, ' '));
</script>

<template>
    <span :class="['inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium', classes]">
        {{ label }}
    </span>
</template>
