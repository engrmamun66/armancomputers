<script setup>
import { computed } from 'vue';
import EmDateTimePicker from '@/components/common/EmDateTimePicker.vue';

const props = defineProps({
    from: { type: String, default: '' },
    to: { type: String, default: '' },
    unified: { type: Boolean, default: false },
    presets: { type: Array, default: null },
});

const emit = defineEmits(['update:from', 'update:to']);

const combinedLabel = computed(() => (props.from || props.to ? `${props.from || '…'} - ${props.to || '…'}` : ''));

function onRangeChange(data) {
    emit('update:from', data.startDateTime);
    emit('update:to', data.endDateTime);
}
</script>

<template>
    <EmDateTimePicker
        v-if="unified"
        :model-value="combinedLabel"
        model-value-type="string"
        classes="px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 w-56"
        :range-picker="true"
        :use-custom-range="presets || undefined"
        placeholder="Select date range"
        @change="onRangeChange"
    />
    <div v-else class="flex items-center gap-2">
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
