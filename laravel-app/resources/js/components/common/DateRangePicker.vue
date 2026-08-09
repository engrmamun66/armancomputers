<script setup>
import EmDateTimePicker from '@/components/common/EmDateTimePicker.vue';

defineProps({
    from: { type: String, default: '' },
    to: { type: String, default: '' },
});

defineEmits(['update:from', 'update:to']);
</script>

<template>
    <div class="flex items-center gap-2">
        <EmDateTimePicker
            :model-value="from"
            model-value-type="date"
            classes="px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 w-36"
            :max-date="to || undefined"
            :keep-empty-the-calendar-first="true"
            placeholder="From"
            @update:model-value="$emit('update:from', $event)"
        />
        <span class="text-slate-400 text-sm">to</span>
        <EmDateTimePicker
            :model-value="to"
            model-value-type="date"
            classes="px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 w-36"
            :min-date="from || undefined"
            :keep-empty-the-calendar-first="true"
            placeholder="To"
            @update:model-value="$emit('update:to', $event)"
        />
    </div>
</template>
