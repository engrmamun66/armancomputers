<script setup>
import { onMounted, ref } from 'vue';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import productsApi from '@/services/products';
import { formatDate } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], required: true } });

const product = ref(null);
const history = ref([]);
const loading = ref(true);

const columns = [
    { key: 'date', label: 'Date' },
    { key: 'type', label: 'Type' },
    { key: 'reference', label: 'Reference' },
    { key: 'quantity', label: 'Quantity', align: 'right' },
    { key: 'stock_before', label: 'Stock Before', align: 'right' },
    { key: 'stock_after', label: 'Stock After', align: 'right' },
    { key: 'user', label: 'User' },
];

onMounted(async () => {
    const { data } = await productsApi.stockHistory(props.id);
    product.value = data.data.product;
    history.value = data.data.history;
    loading.value = false;
});
</script>

<template>
    <AppLayout>
        <LoadingSpinner v-if="loading" />
        <template v-else-if="product">
            <div class="bg-white border border-slate-200 rounded-lg p-4 mb-4 flex flex-wrap gap-x-8 gap-y-2 text-sm">
                <div><span class="text-slate-400">Product:</span> <span class="font-medium text-slate-800">{{ product.name }}</span></div>
                <div><span class="text-slate-400">SKU:</span> <span class="font-medium text-slate-800">{{ product.sku }}</span></div>
                <div><span class="text-slate-400">Current Stock:</span> <span class="font-medium text-slate-800">{{ product.current_stock }}</span></div>
                <div><span class="text-slate-400">Minimum Stock:</span> <span class="font-medium text-slate-800">{{ product.minimum_stock }}</span></div>
            </div>

            <EmptyState v-if="!history.length" title="No stock movements yet." message="Stock In and Stock Out transactions for this product will appear here." />
            <DataTable v-else :columns="columns" :rows="history" row-key="reference">
                <template #cell-date="{ row }">{{ formatDate(row.date) }}</template>
                <template #cell-type="{ row }"><StatusBadge :status="row.type === 'in' ? 'active' : 'due'" /> {{ row.type === 'in' ? 'Stock In' : 'Stock Out' }}</template>
                <template #cell-quantity="{ row }">{{ row.type === 'in' ? '+' : '−' }}{{ row.quantity }}</template>
            </DataTable>
        </template>
    </AppLayout>
</template>
