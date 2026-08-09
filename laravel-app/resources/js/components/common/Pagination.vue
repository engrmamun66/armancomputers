<script setup>
import { computed } from 'vue';

const props = defineProps({
    meta: {
        type: Object,
        required: true,
        // { current_page, last_page, total, per_page }
    },
});

const emit = defineEmits(['change']);

const pages = computed(() => {
    const total = props.meta.last_page || 1;
    const current = props.meta.current_page || 1;
    const delta = 1;
    const range = [];
    for (let i = Math.max(1, current - delta); i <= Math.min(total, current + delta); i++) {
        range.push(i);
    }
    if (range[0] > 1) range.unshift(range[0] > 2 ? '…' : 1);
    if (range[0] === 2) range.unshift(1);
    if (range[range.length - 1] < total) range.push(range[range.length - 1] < total - 1 ? '…' : total);
    if (range[range.length - 1] === total - 1) range.push(total);
    return range;
});

function go(page) {
    if (page === '…' || page === props.meta.current_page) return;
    emit('change', page);
}
</script>

<template>
    <div v-if="meta.last_page > 1" class="flex items-center justify-between flex-wrap gap-3 px-1 py-3">
        <p class="text-sm text-slate-500">
            Showing {{ (meta.current_page - 1) * meta.per_page + 1 }}–{{ Math.min(meta.current_page * meta.per_page, meta.total) }}
            of {{ meta.total }}
        </p>
        <div class="flex items-center gap-1">
            <button
                type="button"
                class="px-3 py-1.5 text-sm rounded-md border border-slate-300 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-slate-50"
                :disabled="meta.current_page <= 1"
                @click="go(meta.current_page - 1)"
            >
                Prev
            </button>
            <button
                v-for="(page, index) in pages"
                :key="index"
                type="button"
                :class="[
                    'min-w-[2.25rem] px-2 py-1.5 text-sm rounded-md',
                    page === meta.current_page ? 'bg-accent-solid text-on-accent-solid' : 'border border-slate-300 hover:bg-slate-50',
                    page === '…' ? 'cursor-default border-none' : '',
                ]"
                @click="go(page)"
            >
                {{ page }}
            </button>
            <button
                type="button"
                class="px-3 py-1.5 text-sm rounded-md border border-slate-300 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-slate-50"
                :disabled="meta.current_page >= meta.last_page"
                @click="go(meta.current_page + 1)"
            >
                Next
            </button>
        </div>
    </div>
</template>
