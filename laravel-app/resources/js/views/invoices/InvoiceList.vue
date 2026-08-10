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
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { formatCurrency, formatDate } from '@/utils/format';

const toast = useToast();
const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'sales.manage');

const DATE_RANGE_PRESETS = ['This Week', 'Last Week', 'This Month', 'Last Month', 'This Year', 'Last Year'];

const columns = [
    { key: 'index', label: '#' },
    { key: 'invoice_number', label: 'Invoice Number' },
    { key: 'customer', label: 'Customer' },
    { key: 'invoice_date', label: 'Date' },
    { key: 'grand_total', label: 'Total', align: 'right' },
    { key: 'paid_amount', label: 'Paid', align: 'right' },
    { key: 'due_amount', label: 'Due', align: 'right' },
    { key: 'payment_status', label: 'Payment', sortable: false },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const filters = reactive({ search: '', date_from: '', date_to: '', sort_by: 'invoice_date', sort_dir: 'desc', page: 1 });

async function loadInvoices() {
    loading.value = true;
    try {
        const { data } = await invoicesApi.list({
            search: filters.search || undefined,
            date_from: filters.date_from || undefined,
            date_to: filters.date_to || undefined,
            sort_by: filters.sort_by,
            sort_dir: filters.sort_dir,
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

const DEFAULT_SORT_BY = 'invoice_date';
const DEFAULT_SORT_DIR = 'desc';

function hasActiveFilters() {
    return !!(
        filters.search ||
        filters.date_from ||
        filters.date_to ||
        filters.sort_by !== DEFAULT_SORT_BY ||
        filters.sort_dir !== DEFAULT_SORT_DIR
    );
}

function clearFilters() {
    Object.assign(filters, {
        search: '',
        date_from: '',
        date_to: '',
        sort_by: DEFAULT_SORT_BY,
        sort_dir: DEFAULT_SORT_DIR,
        page: 1,
    });
}

function onSort(key) {
    if (filters.sort_by === key) {
        filters.sort_dir = filters.sort_dir === 'asc' ? 'desc' : 'asc';
    } else {
        filters.sort_by = key;
        filters.sort_dir = 'asc';
    }
    filters.page = 1;
    loadInvoices();
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
            <DateRangePicker v-model:from="filters.date_from" v-model:to="filters.date_to" unified :presets="[] ?? DATE_RANGE_PRESETS" />
            <button v-if="hasActiveFilters()" type="button" class="px-3 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]" @click="clearFilters">
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
            <DataTable :columns="columns" :rows="rows" row-key="id" :sort-by="filters.sort_by" :sort-dir="filters.sort_dir" @sort="onSort">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-invoice_number="{ row }">
                    <RouterLink :to="{ name: 'invoices.show', params: { id: row.id } }" class="font-medium text-link hover:text-link-hover">
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
                    <div class="flex justify-end gap-2 text-sm">
                        <RouterLink :to="{ name: 'invoices.show', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200 hover:bg-slate-300">View</RouterLink>
                        <RouterLink v-if="canManage && row.sale_id" :to="{ name: 'sales.edit', params: { id: row.sale_id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50 hover:bg-primary-100">Edit Sale</RouterLink>
                    </div>
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
                    <div v-if="canManage && row.sale_id" class="flex gap-2 mt-3 text-sm">
                        <RouterLink :to="{ name: 'sales.edit', params: { id: row.sale_id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50">Edit Sale</RouterLink>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadInvoices(); }" />
        </template>
    </AppLayout>
</template>
