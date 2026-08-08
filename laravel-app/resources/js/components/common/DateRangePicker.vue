<script setup>
defineProps({
    from: { type: String, default: '' },
    to: { type: String, default: '' },
});

defineEmits(['update:from', 'update:to']);
</script>

<template>
    <div class="flex items-center gap-2">
        <input
            type="date"
            :value="from"
            class="px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            @input="$emit('update:from', $event.target.value)"
        />
        <span class="text-slate-400 text-sm">to</span>
        <input
            type="date"
            :value="to"
            class="px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            @input="$emit('update:to', $event.target.value)"
        />
    </div>
</template>
