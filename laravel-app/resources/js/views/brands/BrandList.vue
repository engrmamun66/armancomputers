<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import Pagination from '@/components/common/Pagination.vue';
import SearchInput from '@/components/common/SearchInput.vue';
import Modal from '@/components/common/Modal.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import brandsApi from '@/services/brands';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatDate } from '@/utils/format';

const toast = useToast();
const { confirm } = useConfirm();

const columns = [
    { key: 'index', label: '#' },
    { key: 'name', label: 'Brand Name' },
    { key: 'description', label: 'Description' },
    { key: 'products_count', label: 'Product Count', align: 'center' },
    { key: 'status', label: 'Status' },
    { key: 'created_at', label: 'Created At' },
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

async function loadBrands() {
    loading.value = true;
    try {
        const { data } = await brandsApi.list({
            search: filters.search || undefined,
            status_id: filters.status_id || undefined,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load brands.');
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
    loadBrands();
});

onMounted(async () => {
    await loadStatuses();
    await loadBrands();
});

const showFormModal = ref(false);
const editingBrand = ref(null);
const saving = ref(false);
const form = reactive({ name: '', description: '', status_id: '' });
const formErrors = ref({});

function openCreate() {
    editingBrand.value = null;
    Object.assign(form, { name: '', description: '', status_id: statuses.value[0]?.id ?? '' });
    formErrors.value = {};
    showFormModal.value = true;
}

function openEdit(brand) {
    editingBrand.value = brand;
    Object.assign(form, { name: brand.name, description: brand.description, status_id: brand.status?.id });
    formErrors.value = {};
    showFormModal.value = true;
}

async function submitForm() {
    saving.value = true;
    formErrors.value = {};
    try {
        if (editingBrand.value) {
            await brandsApi.update(editingBrand.value.id, form);
            toast.success('Brand updated successfully.');
        } else {
            await brandsApi.create(form);
            toast.success('Brand created successfully.');
        }
        showFormModal.value = false;
        await loadBrands();
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

async function removeBrand(brand) {
    const ok = await confirm({
        title: 'Delete this brand?',
        message: `"${brand.name}" will be permanently removed. This cannot be undone.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await brandsApi.remove(brand.id);
        toast.success('Brand deleted successfully.');
        await loadBrands();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete brand.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Brands</h1>
            <button type="button" class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700" @click="openCreate">
                + Add Brand
            </button>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search brand name…" />
            </div>
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No brands found."
            :message="filters.search || filters.status_id ? 'No records match your current filters.' : ''"
            :show-clear="!!(filters.search || filters.status_id)"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-description="{ row }">{{ row.description || '—' }}</template>
                <template #cell-status="{ row }"><StatusBadge :status="row.status?.slug" /></template>
                <template #cell-created_at="{ row }">{{ formatDate(row.created_at) }}</template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-3 text-sm">
                        <button type="button" class="text-blue-600 hover:text-blue-700" @click="openEdit(row)">Edit</button>
                        <button type="button" class="text-rose-600 hover:text-rose-700" @click="removeBrand(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <p class="font-medium text-slate-900">{{ row.name }}</p>
                        <StatusBadge :status="row.status?.slug" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">{{ row.description || '—' }}</p>
                    <p class="text-xs text-slate-400 mt-1">{{ row.products_count }} products</p>
                    <div class="flex gap-3 mt-3 text-sm">
                        <button type="button" class="text-blue-600" @click="openEdit(row)">Edit</button>
                        <button type="button" class="text-rose-600" @click="removeBrand(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadBrands(); }" />
        </template>

        <Modal v-model="showFormModal" :title="editingBrand ? 'Edit Brand' : 'Add Brand'" size="sm">
            <form class="space-y-4" @submit.prevent="submitForm">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Brand Name</label>
                    <input v-model="form.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="formErrors.name" class="mt-1 text-xs text-rose-600">{{ formErrors.name[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Description</label>
                    <textarea v-model="form.description" rows="3" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"></textarea>
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
                    class="px-4 py-2 text-sm rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-60"
                    @click="submitForm"
                >
                    {{ saving ? 'Saving…' : 'Save' }}
                </button>
            </template>
        </Modal>
    </AppLayout>
</template>
