<script setup>
import { ref, watch } from 'vue';
import api from '@/services/api';

defineProps({
    placeholder: { type: String, default: 'Search customer by name or phone…' },
});

const emit = defineEmits(['select', 'create-new']);

const query = ref('');
const results = ref([]);
const open = ref(false);
const loading = ref(false);
let timer = null;

watch(query, (value) => {
    clearTimeout(timer);
    if (!value.trim()) {
        results.value = [];
        open.value = false;
        return;
    }
    timer = setTimeout(() => search(value), 300);
});

async function search(value) {
    loading.value = true;
    try {
        const { data } = await api.get('/customers', { params: { search: value, per_page: 8 } });
        results.value = data.data;
        open.value = true;
    } finally {
        loading.value = false;
    }
}

function select(customer) {
    emit('select', customer);
    query.value = '';
    results.value = [];
    open.value = false;
}

function createNew() {
    emit('create-new', query.value);
    query.value = '';
    results.value = [];
    open.value = false;
}

function closeSoon() {
    setTimeout(() => (open.value = false), 150);
}
</script>

<template>
    <div class="relative">
        <input
            v-model="query"
            type="text"
            :placeholder="placeholder"
            class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            @focus="results.length && (open = true)"
            @blur="closeSoon"
        />
        <div v-if="open" class="absolute z-20 mt-1 w-full bg-white border border-slate-200 rounded-md shadow-lg max-h-64 overflow-y-auto">
            <p v-if="loading" class="px-3 py-2 text-sm text-slate-400">Searching…</p>
            <template v-else>
                <button
                    v-for="customer in results"
                    :key="customer.id"
                    type="button"
                    class="w-full text-left px-3 py-2 hover:bg-slate-50 text-sm border-b border-slate-100 last:border-0"
                    @mousedown.prevent="select(customer)"
                >
                    <span class="font-medium text-slate-800">{{ customer.name }}</span>
                    <span class="text-slate-400"> · {{ customer.phone || customer.email || 'No contact info' }}</span>
                </button>
                <button
                    type="button"
                    class="w-full text-left px-3 py-2 hover:bg-primary-50 text-sm text-primary-600 font-medium"
                    @mousedown.prevent="createNew"
                >
                    + Add "{{ query }}" as a new customer
                </button>
            </template>
        </div>
    </div>
</template>
