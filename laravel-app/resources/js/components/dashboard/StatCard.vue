<script setup>
import Icon from '@/components/common/Icon.vue';

defineProps({
    label: { type: String, required: true },
    value: { type: [String, Number], required: true },
    icon: { type: String, default: 'dashboard' },
    tone: { type: String, default: 'default' }, // default | warning | danger | success
    emphasize: { type: Boolean, default: false },
});

const toneClasses = {
    default: 'bg-primary-50 text-primary-600',
    warning: 'bg-amber-50 text-amber-600',
    danger: 'bg-rose-50 text-rose-600',
    success: 'bg-emerald-50 text-emerald-600',
};

const valueToneClasses = {
    default: 'text-slate-900',
    warning: 'text-amber-600',
    danger: 'text-rose-600',
    success: 'text-emerald-600',
};
</script>

<template>
    <div
        class="bg-white border rounded-lg p-4 flex items-center gap-3"
        :class="emphasize ? 'border-2 ' + (tone === 'success' ? 'border-emerald-200' : tone === 'danger' ? 'border-rose-200' : 'border-primary-200') : 'border-slate-200'"
    >
        <div :class="['rounded-md flex items-center justify-center shrink-0', emphasize ? 'h-12 w-12' : 'h-10 w-10', toneClasses[tone] || toneClasses.default]">
            <Icon :name="icon" :class="emphasize ? 'h-6 w-6' : 'h-5 w-5'" />
        </div>
        <div class="min-w-0">
            <p class="text-xs text-slate-500 truncate">{{ label }}</p>
            <p
                class="font-bold truncate"
                :class="[emphasize ? 'text-2xl' : 'text-lg font-semibold', emphasize ? (valueToneClasses[tone] || valueToneClasses.default) : 'text-slate-900']"
            >
                {{ value }}
            </p>
        </div>
    </div>
</template>
