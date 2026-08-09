<script setup>
import { onMounted, ref } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import customersApi from '@/services/customers';
import { formatCurrency, formatDate } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], required: true } });

const customer = ref(null);
const purchases = ref([]);
const loading = ref(true);

const columns = [
    { key: 'reference_no', label: 'Reference No' },
    { key: 'sale_date', label: 'Date' },
    { key: 'grand_total', label: 'Total', align: 'right' },
    { key: 'paid_amount', label: 'Paid', align: 'right' },
    { key: 'due_amount', label: 'Due', align: 'right' },
    { key: 'payment_status', label: 'Payment' },
];

onMounted(async () => {
    const { data } = await customersApi.get(props.id);
    customer.value = data.data.customer;
    purchases.value = data.data.purchases;
    loading.value = false;
});
</script>

<template>
    <AppLayout>
        <LoadingSpinner v-if="loading" />
        <template v-else-if="customer">
            <div class="flex items-center justify-between mb-4">
                <h1 class="text-lg font-semibold text-slate-900">{{ customer.name }}</h1>
                <RouterLink :to="{ name: 'customers.index' }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Back</RouterLink>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6 mb-6">
                <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-4 text-sm">
                    <div><dt class="text-slate-400">Phone</dt><dd class="text-slate-800 font-medium">{{ customer.phone || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Email</dt><dd class="text-slate-800 font-medium">{{ customer.email || '—' }}</dd></div>
                    <div class="sm:col-span-2"><dt class="text-slate-400">Address</dt><dd class="text-slate-700">{{ customer.address || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Status</dt><dd><StatusBadge :status="customer.status?.slug" /></dd></div>
                    <div><dt class="text-slate-400">Total Purchases</dt><dd class="text-slate-800 font-medium">{{ customer.total_purchases }}</dd></div>
                    <div><dt class="text-slate-400">Total Paid</dt><dd class="text-slate-800 font-medium">{{ formatCurrency(customer.total_paid) }}</dd></div>
                    <div>
                        <dt class="text-slate-400">Total Due</dt>
                        <dd class="font-medium" :class="customer.total_due > 0 ? 'text-rose-600' : 'text-slate-800'">{{ formatCurrency(customer.total_due) }}</dd>
                    </div>
                </dl>
            </div>

            <h2 class="text-sm font-semibold text-slate-700 mb-2">Purchase History</h2>
            <EmptyState v-if="!purchases.length" title="No purchases yet." />
            <DataTable v-else :columns="columns" :rows="purchases" row-key="id">
                <template #cell-sale_date="{ row }">{{ formatDate(row.sale_date) }}</template>
                <template #cell-grand_total="{ row }">{{ formatCurrency(row.grand_total) }}</template>
                <template #cell-paid_amount="{ row }">{{ formatCurrency(row.paid_amount) }}</template>
                <template #cell-due_amount="{ row }">{{ formatCurrency(row.due_amount) }}</template>
                <template #cell-payment_status="{ row }"><StatusBadge :status="row.payment_status" /></template>
            </DataTable>
        </template>
    </AppLayout>
</template>
