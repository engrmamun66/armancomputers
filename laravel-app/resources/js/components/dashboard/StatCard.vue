<script setup>
import Icon from '@/components/common/Icon.vue';

defineProps({
    label: { type: String, required: true },
    value: { type: [String, Number], required: true },
    icon: { type: String, default: 'dashboard' },
    tone: { type: String, default: 'default' }, // default | warning | danger
});

const toneClasses = {
    default: 'bg-blue-50 text-blue-600',
    warning: 'bg-amber-50 text-amber-600',
    danger: 'bg-rose-50 text-rose-600',
};
</script>

<template>
    <div class="bg-white border border-slate-200 rounded-lg p-4 flex items-center gap-3">
        <div :class="['h-10 w-10 rounded-md flex items-center justify-center shrink-0', toneClasses[tone] || toneClasses.default]">
            <Icon :name="icon" class="h-5 w-5" />
        </div>
        <div class="min-w-0">
            <p class="text-xs text-slate-500 truncate">{{ label }}</p>
            <p class="text-lg font-semibold text-slate-900 truncate">{{ value }}</p>
        </div>
    </div>
</template>
