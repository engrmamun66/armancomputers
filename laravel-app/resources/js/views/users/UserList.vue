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
import usersApi from '@/services/users';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatDateTime } from '@/utils/format';

const toast = useToast();
const { confirm } = useConfirm();

const columns = [
    { key: 'index', label: '#' },
    { key: 'name', label: 'Name' },
    { key: 'email', label: 'Email' },
    { key: 'role', label: 'Role' },
    { key: 'status', label: 'Status' },
    { key: 'last_login_at', label: 'Last Login' },
    { key: 'created_at', label: 'Created At' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const roles = ref([]);
const statuses = ref([]);

const filters = reactive({ search: '', role_id: '', status_id: '', sort_by: 'created_at', sort_dir: 'desc', page: 1 });

async function loadLookups() {
    const [roleRes, statusRes] = await Promise.all([lookups.roles(), lookups.statuses('general')]);
    roles.value = roleRes.data.data;
    statuses.value = statusRes.data.data;
}

function onSort(key) {
    if (filters.sort_by === key) {
        filters.sort_dir = filters.sort_dir === 'asc' ? 'desc' : 'asc';
    } else {
        filters.sort_by = key;
        filters.sort_dir = 'asc';
    }
    filters.page = 1;
    loadUsers();
}

async function loadUsers() {
    loading.value = true;
    try {
        const { data } = await usersApi.list({
            search: filters.search || undefined,
            role_id: filters.role_id || undefined,
            status_id: filters.status_id || undefined,
            sort_by: filters.sort_by,
            sort_dir: filters.sort_dir,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load users.');
    } finally {
        loading.value = false;
    }
}

function clearFilters() {
    filters.search = '';
    filters.role_id = '';
    filters.status_id = '';
    filters.page = 1;
}

watch([() => filters.search, () => filters.role_id, () => filters.status_id], () => {
    filters.page = 1;
    loadUsers();
});

onMounted(async () => {
    await loadLookups();
    await loadUsers();
});

// --- create/edit modal ---
const showFormModal = ref(false);
const editingUser = ref(null);
const saving = ref(false);
const form = reactive({ name: '', email: '', password: '', role_id: '', status_id: '' });
const formErrors = ref({});

function openCreate() {
    editingUser.value = null;
    Object.assign(form, { name: '', email: '', password: '', role_id: '', status_id: statuses.value[0]?.id ?? '' });
    formErrors.value = {};
    showFormModal.value = true;
}

function openEdit(user) {
    editingUser.value = user;
    Object.assign(form, { name: user.name, email: user.email, password: '', role_id: user.role?.id, status_id: user.status?.id });
    formErrors.value = {};
    showFormModal.value = true;
}

async function submitForm() {
    saving.value = true;
    formErrors.value = {};
    try {
        if (editingUser.value) {
            await usersApi.update(editingUser.value.id, {
                name: form.name,
                email: form.email,
                role_id: form.role_id,
                status_id: form.status_id,
            });
            toast.success('User updated successfully.');
        } else {
            await usersApi.create(form);
            toast.success('User created successfully.');
        }
        showFormModal.value = false;
        await loadUsers();
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

// --- reset password modal ---
const showResetModal = ref(false);
const resetTarget = ref(null);
const resetPassword = ref('');
const resetErrors = ref({});
const resetting = ref(false);

function openReset(user) {
    resetTarget.value = user;
    resetPassword.value = '';
    resetErrors.value = {};
    showResetModal.value = true;
}

async function submitReset() {
    resetting.value = true;
    resetErrors.value = {};
    try {
        await usersApi.resetPassword(resetTarget.value.id, { password: resetPassword.value });
        toast.success('Password reset successfully.');
        showResetModal.value = false;
    } catch (error) {
        if (error.response?.status === 422) {
            resetErrors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        resetting.value = false;
    }
}

// --- activate / deactivate ---
async function toggleStatus(user) {
    const activeId = statuses.value.find((s) => s.slug === 'active')?.id;
    const inactiveId = statuses.value.find((s) => s.slug === 'inactive')?.id;
    const nextStatusId = user.status?.slug === 'active' ? inactiveId : activeId;

    try {
        await usersApi.update(user.id, {
            name: user.name,
            email: user.email,
            role_id: user.role.id,
            status_id: nextStatusId,
        });
        toast.success(`User ${user.status?.slug === 'active' ? 'deactivated' : 'activated'}.`);
        await loadUsers();
    } catch {
        toast.error('Failed to update status.');
    }
}

// --- delete ---
async function removeUser(user) {
    const ok = await confirm({
        title: 'Delete this user?',
        message: `"${user.name}" will lose access immediately. This action cannot be undone.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await usersApi.remove(user.id);
        toast.success('User deleted successfully.');
        await loadUsers();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete user.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Users</h1>
            <button type="button" class="px-4 py-2 text-sm font-medium text-on-accent-solid bg-accent-solid rounded-md hover:bg-accent-solid-hover" @click="openCreate">
                + Add User
            </button>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search name or email…" />
            </div>
            <select v-model="filters.role_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Roles</option>
                <option v-for="role in roles" :key="role.id" :value="role.id">{{ role.name }}</option>
            </select>
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No users found."
            :message="filters.search || filters.role_id || filters.status_id ? 'No records match your current filters.' : ''"
            :show-clear="!!(filters.search || filters.role_id || filters.status_id)"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id" :sort-by="filters.sort_by" :sort-dir="filters.sort_dir" @sort="onSort">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-role="{ row }">{{ row.role?.name }}</template>
                <template #cell-status="{ row }"><StatusBadge :status="row.status?.slug" /></template>
                <template #cell-last_login_at="{ row }">{{ row.last_login_at ? formatDateTime(row.last_login_at) : 'Never' }}</template>
                <template #cell-created_at="{ row }">{{ formatDateTime(row.created_at) }}</template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-2 text-sm">
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50 hover:bg-primary-100" @click="openEdit(row)">Edit</button>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200 hover:bg-slate-300" @click="toggleStatus(row)">
                            {{ row.status?.slug === 'active' ? 'Deactivate' : 'Activate' }}
                        </button>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-amber-700 bg-amber-50 hover:bg-amber-100" @click="openReset(row)">Reset Password</button>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50 hover:bg-rose-100" @click="removeUser(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <p class="font-medium text-slate-900">{{ row.name }}</p>
                        <StatusBadge :status="row.status?.slug" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">{{ row.email }}</p>
                    <p class="text-sm text-slate-500">Role: {{ row.role?.name }}</p>
                    <p class="text-xs text-slate-400 mt-1">Last login: {{ row.last_login_at ? formatDateTime(row.last_login_at) : 'Never' }}</p>
                    <div class="flex flex-wrap gap-2 mt-3 text-sm">
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50" @click="openEdit(row)">Edit</button>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200" @click="toggleStatus(row)">
                            {{ row.status?.slug === 'active' ? 'Deactivate' : 'Activate' }}
                        </button>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-amber-700 bg-amber-50" @click="openReset(row)">Reset Password</button>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50" @click="removeUser(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadUsers(); }" />
        </template>

        <Modal v-model="showFormModal" :title="editingUser ? 'Edit User' : 'Add User'">
            <form class="space-y-4" @submit.prevent="submitForm">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Name <span class="text-rose-600">*</span></label>
                    <input v-model="form.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="formErrors.name" class="mt-1 text-xs text-rose-600">{{ formErrors.name[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Email <span class="text-rose-600">*</span></label>
                    <input v-model="form.email" type="email" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="formErrors.email" class="mt-1 text-xs text-rose-600">{{ formErrors.email[0] }}</p>
                </div>
                <div v-if="!editingUser">
                    <label class="block text-sm font-medium text-slate-700 mb-1">Password <span class="text-rose-600">*</span></label>
                    <input v-model="form.password" type="password" required minlength="8" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="formErrors.password" class="mt-1 text-xs text-rose-600">{{ formErrors.password[0] }}</p>
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Role <span class="text-rose-600">*</span></label>
                        <select v-model="form.role_id" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md">
                            <option value="" disabled>Select a role</option>
                            <option v-for="role in roles" :key="role.id" :value="role.id">{{ role.name }}</option>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Status <span class="text-rose-600">*</span></label>
                        <select v-model="form.status_id" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md">
                            <option value="" disabled>Select a status</option>
                            <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
                        </select>
                    </div>
                </div>
            </form>
            <template #footer>
                <button type="button" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-onbrand hover:bg-[#d8430f]" @click="showFormModal = false">Cancel</button>
                <button
                    type="button"
                    :disabled="saving"
                    class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60"
                    @click="submitForm"
                >
                    {{ saving ? 'Saving…' : 'Save' }}
                </button>
            </template>
        </Modal>

        <Modal v-model="showResetModal" title="Reset Password" size="sm">
            <form class="space-y-4" @submit.prevent="submitReset">
                <p class="text-sm text-slate-500">Set a new password for {{ resetTarget?.name }}.</p>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">New Password <span class="text-rose-600">*</span></label>
                    <input v-model="resetPassword" type="password" required minlength="8" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="resetErrors.password" class="mt-1 text-xs text-rose-600">{{ resetErrors.password[0] }}</p>
                </div>
            </form>
            <template #footer>
                <button type="button" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-onbrand hover:bg-[#d8430f]" @click="showResetModal = false">Cancel</button>
                <button
                    type="button"
                    :disabled="resetting"
                    class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60"
                    @click="submitReset"
                >
                    {{ resetting ? 'Saving…' : 'Reset Password' }}
                </button>
            </template>
        </Modal>
    </AppLayout>
</template>
