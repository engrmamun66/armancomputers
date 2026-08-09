<script setup>
import { onMounted, ref } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import DataTable from '@/components/tables/DataTable.vue';
import purchasesApi from '@/services/purchases';
import { formatCurrency, formatDate, formatDateTime } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], required: true } });

const purchase = ref(null);
const loading = ref(true);

const columns = [
    { key: 'product_name', label: 'Product' },
    { key: 'sku', label: 'SKU' },
    { key: 'quantity', label: 'Qty', align: 'right' },
    { key: 'unit_price', label: 'Unit Price', align: 'right' },
    { key: 'total_price', label: 'Total', align: 'right' },
];

onMounted(async () => {
    const { data } = await purchasesApi.get(props.id);
    purchase.value = data.data;
    loading.value = false;
});
</script>

<template>
    <AppLayout>
        <LoadingSpinner v-if="loading" />
        <template v-else-if="purchase">
            <div class="flex items-center justify-between mb-4">
                <h1 class="text-lg font-semibold text-slate-900">{{ purchase.reference_no }}</h1>
                <div class="flex gap-3">
                    <RouterLink :to="{ name: 'purchases.edit', params: { id } }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Edit</RouterLink>
                    <RouterLink :to="{ name: 'purchases.index' }" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover">Back</RouterLink>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6 mb-6">
                <dl class="grid grid-cols-1 sm:grid-cols-3 gap-x-6 gap-y-4 text-sm">
                    <div><dt class="text-slate-400">Supplier</dt><dd class="text-slate-800 font-medium">{{ purchase.supplier_name || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Supplier Phone</dt><dd class="text-slate-800 font-medium">{{ purchase.supplier_phone || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Purchase Date</dt><dd class="text-slate-800 font-medium">{{ formatDate(purchase.purchase_date) }}</dd></div>
                    <div><dt class="text-slate-400">Status</dt><dd><StatusBadge :status="purchase.status?.slug" /></dd></div>
                    <div><dt class="text-slate-400">Created By</dt><dd class="text-slate-800 font-medium">{{ purchase.created_by }}</dd></div>
                    <div><dt class="text-slate-400">Created At</dt><dd class="text-slate-800 font-medium">{{ formatDateTime(purchase.created_at) }}</dd></div>
                    <div v-if="purchase.notes" class="sm:col-span-3"><dt class="text-slate-400">Notes</dt><dd class="text-slate-700">{{ purchase.notes }}</dd></div>
                </dl>
            </div>

            <DataTable :columns="columns" :rows="purchase.items" row-key="id">
                <template #cell-unit_price="{ row }">{{ formatCurrency(row.unit_price) }}</template>
                <template #cell-total_price="{ row }">{{ formatCurrency(row.total_price) }}</template>
            </DataTable>

            <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-md ml-auto mt-4 space-y-2 text-sm">
                <div class="flex justify-between"><span class="text-slate-500">Subtotal</span><span>{{ formatCurrency(purchase.subtotal) }}</span></div>
                <div class="flex justify-between"><span class="text-slate-500">Discount</span><span>{{ formatCurrency(purchase.discount) }}</span></div>
                <div class="flex justify-between"><span class="text-slate-500">Additional Cost</span><span>{{ formatCurrency(purchase.additional_cost) }}</span></div>
                <div class="flex justify-between text-base font-semibold border-t border-slate-200 pt-2">
                    <span>Grand Total</span><span>{{ formatCurrency(purchase.grand_total) }}</span>
                </div>
            </div>
        </template>
    </AppLayout>
</template>
