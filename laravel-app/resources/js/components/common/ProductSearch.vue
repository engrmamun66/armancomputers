<script setup>
import { ref, watch } from 'vue';
import api from '@/services/api';
import ProductThumbnail from './ProductThumbnail.vue';

const props = defineProps({
    excludeIds: { type: Array, default: () => [] },
    placeholder: { type: String, default: 'Search product by name or barcode…' },
    allowCreate: { type: Boolean, default: false },
    // Purchases still need to restock/log inventory against an inactive
    // product, so this defaults to allowed — Sales can't sell one, so it
    // opts out explicitly.
    allowInactive: { type: Boolean, default: true },
});

function isSelectable(product) {
    return props.allowInactive || product.status?.slug === 'active';
}

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
        const { data } = await api.get('/products', { params: { search: value, per_page: 8 } });
        results.value = data.data.filter((product) => !props.excludeIds.includes(product.id));
        open.value = true;
    } finally {
        loading.value = false;
    }
}

function select(product) {
    emit('select', product);
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
        <div
            v-if="open"
            class="absolute z-20 mt-1 w-full bg-white border border-slate-200 rounded-md shadow-lg max-h-64 overflow-y-auto"
        >
            <p v-if="loading" class="px-3 py-2 text-sm text-slate-400">Searching…</p>
            <template v-else>
                <button
                    v-for="product in results"
                    :key="product.id"
                    type="button"
                    :disabled="!isSelectable(product)"
                    class="w-full text-left px-3 py-2 flex items-center justify-between gap-2 text-sm border-b border-slate-100 last:border-0"
                    :class="isSelectable(product) ? 'hover:bg-slate-50' : 'opacity-50 cursor-not-allowed'"
                    @mousedown.prevent="isSelectable(product) && select(product)"
                >
                    <span class="flex items-center gap-2 min-w-0">
                        <ProductThumbnail :src="product.image_url" :alt="product.name" size="h-8 w-8" />
                        <span class="min-w-0">
                            <span class="font-medium text-slate-800">{{ product.name }}</span>
                            <span class="text-slate-400"> · {{ product.brand?.name }}</span>
                        </span>
                    </span>
                    <span class="flex items-center gap-2 whitespace-nowrap">
                        <span v-if="product.status?.slug !== 'active'" class="text-xs font-medium text-rose-600">Inactive</span>
                        <span :class="product.current_stock <= 0 ? 'text-rose-600' : 'text-slate-500'" class="text-xs">
                            {{ product.current_stock <= 0 ? 'Out of stock' : `Stock: ${product.current_stock}` }}
                        </span>
                    </span>
                </button>
                <p v-if="!results.length" class="px-3 py-2 text-sm text-slate-400">No products found.</p>
                <button
                    v-if="allowCreate"
                    type="button"
                    class="w-full text-left px-3 py-2 hover:bg-primary-50 text-sm text-primary-600 font-medium"
                    @mousedown.prevent="createNew"
                >
                    + Add "{{ query }}" as a new product
                </button>
            </template>
        </div>
    </div>
</template>
