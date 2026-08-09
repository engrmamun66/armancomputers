<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import Pagination from '@/components/common/Pagination.vue';
import SearchInput from '@/components/common/SearchInput.vue';
import DateRangePicker from '@/components/common/DateRangePicker.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import invoicesApi from '@/services/invoices';
import { useToast } from '@/composables/useToast';
import { formatCurrency, formatDate } from '@/utils/format';

const toast = useToast();

const columns = [
    { key: 'index', label: '#' },
    { key: 'invoice_number', label: 'Invoice Number' },
    { key: 'customer', label: 'Customer' },
    { key: 'invoice_date', label: 'Date' },
    { key: 'grand_total', label: 'Total', align: 'right' },
    { key: 'paid_amount', label: 'Paid', align: 'right' },
    { key: 'due_amount', label: 'Due', align: 'right' },
    { key: 'payment_status', label: 'Payment' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const filters = reactive({ search: '', date_from: '', date_to: '', page: 1 });

async function loadInvoices() {
    loading.value = true;
    try {
        const { data } = await invoicesApi.list({
            search: filters.search || undefined,
            date_from: filters.date_from || undefined,
            date_to: filters.date_to || undefined,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load invoices.');
    } finally {
        loading.value = false;
    }
}

function hasActiveFilters() {
    return !!(filters.search || filters.date_from || filters.date_to);
}

function clearFilters() {
    Object.assign(filters, { search: '', date_from: '', date_to: '', page: 1 });
}

watch([() => filters.search, () => filters.date_from, () => filters.date_to], () => {
    filters.page = 1;
    loadInvoices();
});

onMounted(loadInvoices);
</script>

<template>
    <AppLayout>
        <h1 class="text-lg font-semibold text-slate-900 mb-4">Invoices</h1>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search invoice number or customer…" />
            </div>
            <DateRangePicker v-model:from="filters.date_from" v-model:to="filters.date_to" />
            <button v-if="hasActiveFilters()" type="button" class="text-sm text-primary-600 hover:text-primary-700" @click="clearFilters">
                Reset Filters
            </button>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No invoices found."
            :message="hasActiveFilters() ? 'No records match your current filters.' : ''"
            :show-clear="hasActiveFilters()"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-invoice_number="{ row }">
                    <RouterLink :to="{ name: 'invoices.show', params: { id: row.id } }" class="font-medium text-primary-600 hover:text-primary-700">
                        {{ row.invoice_number }}
                    </RouterLink>
                </template>
                <template #cell-customer="{ row }">{{ row.customer?.name }}</template>
                <template #cell-invoice_date="{ row }">{{ formatDate(row.invoice_date) }}</template>
                <template #cell-grand_total="{ row }">{{ formatCurrency(row.grand_total) }}</template>
                <template #cell-paid_amount="{ row }">{{ formatCurrency(row.paid_amount) }}</template>
                <template #cell-due_amount="{ row }">
                    <span :class="row.due_amount > 0 ? 'text-rose-600 font-medium' : ''">{{ formatCurrency(row.due_amount) }}</span>
                </template>
                <template #cell-payment_status="{ row }"><StatusBadge :status="row.payment_status" /></template>
                <template #cell-actions="{ row }">
                    <RouterLink :to="{ name: 'invoices.show', params: { id: row.id } }" class="text-sm text-slate-500 hover:text-slate-700">View</RouterLink>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <RouterLink :to="{ name: 'invoices.show', params: { id: row.id } }" class="font-medium text-slate-900">{{ row.invoice_number }}</RouterLink>
                        <StatusBadge :status="row.payment_status" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">{{ row.customer?.name }} · {{ formatDate(row.invoice_date) }}</p>
                    <p class="text-sm text-slate-500">Total: {{ formatCurrency(row.grand_total) }} · Due: {{ formatCurrency(row.due_amount) }}</p>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadInvoices(); }" />
        </template>
    </AppLayout>
</template>
