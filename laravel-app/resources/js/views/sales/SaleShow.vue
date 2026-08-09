<script setup>
import { onMounted, ref } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import DataTable from '@/components/tables/DataTable.vue';
import salesApi from '@/services/sales';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { formatCurrency, formatDate, formatDateTime, formatWarranty } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], required: true } });
const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'sales.manage') && auth.roleSlug !== 'staff';

const sale = ref(null);
const loading = ref(true);

const columns = [
    { key: 'product_name', label: 'Product' },
    { key: 'sku', label: 'SKU' },
    { key: 'quantity', label: 'Qty', align: 'right' },
    { key: 'unit_price', label: 'Unit Price', align: 'right' },
    { key: 'warranty', label: 'Warranty', sortable: false },
    { key: 'total_price', label: 'Total', align: 'right' },
];

onMounted(async () => {
    const { data } = await salesApi.get(props.id);
    sale.value = data.data;
    loading.value = false;
});
</script>

<template>
    <AppLayout>
        <LoadingSpinner v-if="loading" />
        <template v-else-if="sale">
            <div class="flex items-center justify-between mb-4">
                <h1 class="text-lg font-semibold text-slate-900">{{ sale.reference_no }}</h1>
                <div class="flex gap-3">
                    <RouterLink v-if="sale.invoice_id" :to="{ name: 'invoices.show', params: { id: sale.invoice_id } }" class="px-4 py-2 text-sm rounded-md border border-slate-300">
                        View Invoice
                    </RouterLink>
                    <RouterLink v-if="canManage" :to="{ name: 'sales.edit', params: { id } }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Edit</RouterLink>
                    <RouterLink :to="{ name: 'sales.index' }" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover">Back</RouterLink>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6 mb-6">
                <dl class="grid grid-cols-1 sm:grid-cols-3 gap-x-6 gap-y-4 text-sm">
                    <div><dt class="text-slate-400">Customer</dt><dd class="text-slate-800 font-medium">{{ sale.customer?.name }}</dd></div>
                    <div><dt class="text-slate-400">Customer Phone</dt><dd class="text-slate-800 font-medium">{{ sale.customer?.phone || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Sale Date</dt><dd class="text-slate-800 font-medium">{{ formatDate(sale.sale_date) }}</dd></div>
                    <div>
                        <dt class="text-slate-400">Warranty</dt>
                        <dd class="text-slate-800 font-medium">
                            {{ formatWarranty(sale.sale_date, sale.warranty_end_date) || '—' }}
                            <span v-if="sale.warranty_end_date" class="text-slate-400 font-normal">(until {{ formatDate(sale.warranty_end_date) }})</span>
                        </dd>
                    </div>
                    <div><dt class="text-slate-400">Status</dt><dd><StatusBadge :status="sale.status?.slug" /></dd></div>
                    <div><dt class="text-slate-400">Payment</dt><dd><StatusBadge :status="sale.payment_status" /> <span class="text-slate-500">({{ sale.payment_method }})</span></dd></div>
                    <div><dt class="text-slate-400">Created By</dt><dd class="text-slate-800 font-medium">{{ sale.created_by }}</dd></div>
                    <div><dt class="text-slate-400">Created At</dt><dd class="text-slate-800 font-medium">{{ formatDateTime(sale.created_at) }}</dd></div>
                    <div v-if="sale.notes" class="sm:col-span-3"><dt class="text-slate-400">Notes</dt><dd class="text-slate-700">{{ sale.notes }}</dd></div>
                </dl>
            </div>

            <DataTable :columns="columns" :rows="sale.items" row-key="id">
                <template #cell-unit_price="{ row }">{{ formatCurrency(row.unit_price) }}</template>
                <template #cell-warranty>{{ formatWarranty(sale.sale_date, sale.warranty_end_date) || '—' }}</template>
                <template #cell-total_price="{ row }">{{ formatCurrency(row.total_price) }}</template>
            </DataTable>

            <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-md ml-auto mt-4 space-y-2 text-sm">
                <div class="flex justify-between"><span class="text-slate-500">Subtotal</span><span>{{ formatCurrency(sale.subtotal) }}</span></div>
                <div class="flex justify-between"><span class="text-slate-500">Discount</span><span>{{ formatCurrency(sale.discount) }}</span></div>
                <div class="flex justify-between"><span class="text-slate-500">Additional Cost</span><span>{{ formatCurrency(sale.additional_cost) }}</span></div>
                <div class="flex justify-between text-base font-semibold border-t border-slate-200 pt-2">
                    <span>Grand Total</span><span>{{ formatCurrency(sale.grand_total) }}</span>
                </div>
                <div class="flex justify-between"><span class="text-slate-500">Paid</span><span>{{ formatCurrency(sale.paid_amount) }}</span></div>
                <div class="flex justify-between font-medium">
                    <span :class="sale.due_amount > 0 ? 'text-rose-600' : ''">Due</span>
                    <span :class="sale.due_amount > 0 ? 'text-rose-600' : ''">{{ formatCurrency(sale.due_amount) }}</span>
                </div>
            </div>
        </template>
    </AppLayout>
</template>
