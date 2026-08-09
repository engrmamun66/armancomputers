<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import Pagination from '@/components/common/Pagination.vue';
import SearchInput from '@/components/common/SearchInput.vue';
import Modal from '@/components/common/Modal.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import customersApi from '@/services/customers';
import lookups from '@/services/lookups';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatCurrency } from '@/utils/format';

const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'customers.manage');
const toast = useToast();
const { confirm } = useConfirm();

const columns = [
    { key: 'index', label: '#' },
    { key: 'name', label: 'Customer Name' },
    { key: 'phone', label: 'Phone' },
    { key: 'email', label: 'Email' },
    { key: 'total_purchases', label: 'Total Purchases', align: 'right' },
    { key: 'total_paid', label: 'Total Paid', align: 'right' },
    { key: 'total_due', label: 'Total Due', align: 'right' },
    { key: 'status', label: 'Status' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const statuses = ref([]);
const filters = reactive({ search: '', status_id: '', page: 1 });

async function loadStatuses() {
    const { data } = await lookups.statuses('general');
    statuses.value = data.data;
}

async function loadCustomers() {
    loading.value = true;
    try {
        const { data } = await customersApi.list({
            search: filters.search || undefined,
            status_id: filters.status_id || undefined,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load customers.');
    } finally {
        loading.value = false;
    }
}

function clearFilters() {
    filters.search = '';
    filters.status_id = '';
    filters.page = 1;
}

watch([() => filters.search, () => filters.status_id], () => {
    filters.page = 1;
    loadCustomers();
});

onMounted(async () => {
    await loadStatuses();
    await loadCustomers();
});

const showFormModal = ref(false);
const editingCustomer = ref(null);
const saving = ref(false);
const form = reactive({ name: '', phone: '', email: '', address: '', status_id: '' });
const formErrors = ref({});

function openCreate() {
    editingCustomer.value = null;
    Object.assign(form, { name: '', phone: '', email: '', address: '', status_id: statuses.value[0]?.id ?? '' });
    formErrors.value = {};
    showFormModal.value = true;
}

function openEdit(customer) {
    editingCustomer.value = customer;
    Object.assign(form, {
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        status_id: customer.status?.id,
    });
    formErrors.value = {};
    showFormModal.value = true;
}

async function submitForm() {
    saving.value = true;
    formErrors.value = {};
    try {
        if (editingCustomer.value) {
            await customersApi.update(editingCustomer.value.id, form);
            toast.success('Customer updated successfully.');
        } else {
            await customersApi.create(form);
            toast.success('Customer created successfully.');
        }
        showFormModal.value = false;
        await loadCustomers();
    } catch (error) {
        if (error.response?.status === 422) {
            formErrors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        saving.value = false;
    }
}

async function removeCustomer(customer) {
    const ok = await confirm({
        title: 'Delete this customer?',
        message: `"${customer.name}" will be archived. Their purchase history is preserved.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await customersApi.remove(customer.id);
        toast.success('Customer deleted successfully.');
        await loadCustomers();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete customer.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Customers</h1>
            <button v-if="canManage" type="button" class="px-4 py-2 text-sm font-medium text-white bg-primary-600 rounded-md hover:bg-primary-700" @click="openCreate">
                + Add Customer
            </button>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search name, phone, or email…" />
            </div>
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No customers found."
            :message="filters.search || filters.status_id ? 'No records match your current filters.' : ''"
            :show-clear="!!(filters.search || filters.status_id)"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-name="{ row }">
                    <RouterLink :to="{ name: 'customers.show', params: { id: row.id } }" class="font-medium text-slate-800 hover:text-primary-600">
                        {{ row.name }}
                    </RouterLink>
                </template>
                <template #cell-phone="{ row }">{{ row.phone || '—' }}</template>
                <template #cell-email="{ row }">{{ row.email || '—' }}</template>
                <template #cell-total_purchases="{ row }">{{ row.total_purchases }}</template>
                <template #cell-total_paid="{ row }">{{ formatCurrency(row.total_paid) }}</template>
                <template #cell-total_due="{ row }">
                    <span :class="row.total_due > 0 ? 'text-rose-600 font-medium' : ''">{{ formatCurrency(row.total_due) }}</span>
                </template>
                <template #cell-status="{ row }"><StatusBadge :status="row.status?.slug" /></template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-3 text-sm">
                        <RouterLink :to="{ name: 'customers.show', params: { id: row.id } }" class="text-slate-500 hover:text-slate-700">View</RouterLink>
                        <button v-if="canManage" type="button" class="text-primary-600 hover:text-primary-700" @click="openEdit(row)">Edit</button>
                        <button v-if="canManage" type="button" class="text-rose-600 hover:text-rose-700" @click="removeCustomer(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <RouterLink :to="{ name: 'customers.show', params: { id: row.id } }" class="font-medium text-slate-900">{{ row.name }}</RouterLink>
                        <StatusBadge :status="row.status?.slug" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">{{ row.phone || row.email || 'No contact info' }}</p>
                    <p class="text-sm text-slate-500">Paid: {{ formatCurrency(row.total_paid) }} · Due:
                        <span :class="row.total_due > 0 ? 'text-rose-600 font-medium' : ''">{{ formatCurrency(row.total_due) }}</span>
                    </p>
                    <div class="flex gap-3 mt-3 text-sm">
                        <button v-if="canManage" type="button" class="text-primary-600" @click="openEdit(row)">Edit</button>
                        <button v-if="canManage" type="button" class="text-rose-600" @click="removeCustomer(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadCustomers(); }" />
        </template>

        <Modal v-model="showFormModal" :title="editingCustomer ? 'Edit Customer' : 'Add Customer'">
            <form class="space-y-4" @submit.prevent="submitForm">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Customer Name</label>
                    <input v-model="form.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="formErrors.name" class="mt-1 text-xs text-rose-600">{{ formErrors.name[0] }}</p>
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Phone</label>
                        <input v-model="form.phone" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
                        <input v-model="form.email" type="email" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                        <p v-if="formErrors.email" class="mt-1 text-xs text-rose-600">{{ formErrors.email[0] }}</p>
                    </div>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Address</label>
                    <textarea v-model="form.address" rows="2" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"></textarea>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
                    <select v-model="form.status_id" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md">
                        <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
                    </select>
                </div>
            </form>
            <template #footer>
                <button type="button" class="px-4 py-2 text-sm rounded-md border border-slate-300" @click="showFormModal = false">Cancel</button>
                <button
                    type="button"
                    :disabled="saving"
                    class="px-4 py-2 text-sm rounded-md bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-60"
                    @click="submitForm"
                >
                    {{ saving ? 'Saving…' : 'Save' }}
                </button>
            </template>
        </Modal>
    </AppLayout>
</template>
