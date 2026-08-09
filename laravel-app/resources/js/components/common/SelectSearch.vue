<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import Icon from '@/components/common/Icon.vue';

const props = defineProps({
    modelValue: { type: [String, Number], default: null },
    options: { type: Array, default: () => [] }, // [{ value, label }]
    placeholder: { type: String, default: 'Select…' },
    searchPlaceholder: { type: String, default: 'Search…' },
    allowCreate: { type: Boolean, default: false },
    createFn: { type: Function, default: null }, // async (text) => ({ value, label })
    createLabel: { type: String, default: 'Add' },
    disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'created']);

const open = ref(false);
const query = ref('');
const creating = ref(false);
const highlighted = ref(-1);
const rootEl = ref(null);
const inputEl = ref(null);

const selectedOption = computed(() => props.options.find((option) => option.value === props.modelValue) ?? null);

const filteredOptions = computed(() => {
    const q = query.value.trim().toLowerCase();
    if (!q) return props.options;
    return props.options.filter((option) => option.label.toLowerCase().includes(q));
});

const exactMatch = computed(() => props.options.some((option) => option.label.toLowerCase() === query.value.trim().toLowerCase()));
const showCreateOption = computed(() => props.allowCreate && query.value.trim().length > 0 && !exactMatch.value);

watch(open, (value) => {
    if (value) {
        query.value = '';
        highlighted.value = -1;
        nextTick(() => inputEl.value?.focus());
    }
});

function toggle() {
    if (props.disabled) return;
    open.value = !open.value;
}

function selectOption(option) {
    emit('update:modelValue', option.value);
    open.value = false;
}

async function createOption() {
    const text = query.value.trim();
    if (!text || !props.createFn || creating.value) return;
    creating.value = true;
    try {
        const option = await props.createFn(text);
        if (option) {
            emit('created', option);
            emit('update:modelValue', option.value);
            open.value = false;
        }
    } finally {
        creating.value = false;
    }
}

function onKeydown(event) {
    const total = filteredOptions.value.length + (showCreateOption.value ? 1 : 0);
    if (event.key === 'ArrowDown') {
        event.preventDefault();
        if (total) highlighted.value = (highlighted.value + 1) % total;
    } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        if (total) highlighted.value = (highlighted.value - 1 + total) % total;
    } else if (event.key === 'Enter') {
        event.preventDefault();
        if (highlighted.value === -1) return;
        if (highlighted.value < filteredOptions.value.length) {
            selectOption(filteredOptions.value[highlighted.value]);
        } else {
            createOption();
        }
    } else if (event.key === 'Escape') {
        open.value = false;
    }
}

function onClickOutside(event) {
    if (rootEl.value && !rootEl.value.contains(event.target)) {
        open.value = false;
    }
}

onMounted(() => document.addEventListener('mousedown', onClickOutside));
onBeforeUnmount(() => document.removeEventListener('mousedown', onClickOutside));
</script>

<template>
    <div ref="rootEl" class="relative">
        <button
            type="button"
            :disabled="disabled"
            class="w-full flex items-center justify-between gap-2 px-3 py-2 text-sm border border-slate-300 rounded-md bg-white text-left focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 disabled:bg-slate-50 disabled:text-slate-400"
            @click="toggle"
        >
            <span class="truncate" :class="selectedOption ? 'text-slate-800' : 'text-slate-400'">{{ selectedOption?.label ?? placeholder }}</span>
            <Icon name="chevron-down" class="h-4 w-4 text-slate-400 shrink-0" />
        </button>

        <div v-if="open" class="absolute z-30 mt-1 w-full bg-white border border-slate-200 rounded-md shadow-lg overflow-hidden">
            <div class="p-2 border-b border-slate-100">
                <input
                    ref="inputEl"
                    v-model="query"
                    type="text"
                    :placeholder="searchPlaceholder"
                    class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded focus:outline-none focus:ring-1 focus:ring-primary-500"
                    @keydown="onKeydown"
                />
            </div>
            <div class="max-h-56 overflow-y-auto">
                <button
                    v-for="(option, index) in filteredOptions"
                    :key="option.value"
                    type="button"
                    class="w-full text-left px-3 py-2 text-sm hover:bg-slate-50 flex items-center justify-between gap-2"
                    :class="[option.value === modelValue ? 'text-primary-700 font-medium bg-primary-50' : 'text-slate-700', highlighted === index ? 'bg-slate-50' : '']"
                    @mousedown.prevent="selectOption(option)"
                >
                    <span class="truncate">{{ option.label }}</span>
                    <Icon v-if="option.value === modelValue" name="check" class="h-4 w-4 text-primary-600 shrink-0" />
                </button>
                <p v-if="!filteredOptions.length && !showCreateOption" class="px-3 py-2 text-sm text-slate-400">No results found.</p>
                <button
                    v-if="showCreateOption"
                    type="button"
                    :disabled="creating"
                    class="w-full text-left px-3 py-2 text-sm text-primary-600 hover:bg-primary-50 flex items-center gap-2 border-t border-slate-100 disabled:opacity-60"
                    :class="highlighted === filteredOptions.length ? 'bg-primary-50' : ''"
                    @mousedown.prevent="createOption"
                >
                    <Icon name="plus" class="h-4 w-4 shrink-0" />
                    <span class="truncate">{{ creating ? 'Adding…' : `${createLabel} "${query.trim()}"` }}</span>
                </button>
            </div>
        </div>
    </div>
</template>
