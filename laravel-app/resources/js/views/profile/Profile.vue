<script setup>
import { reactive, ref } from 'vue';
import AppLayout from '@/layouts/AppLayout.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import profileApi from '@/services/profile';
import { useAuthStore } from '@/stores/auth';
import { useToast } from '@/composables/useToast';
import { formatDate } from '@/utils/format';

const auth = useAuthStore();
const toast = useToast();

const profileForm = reactive({ name: auth.user?.name || '', email: auth.user?.email || '' });
const profileErrors = ref({});
const savingProfile = ref(false);

async function submitProfile() {
    savingProfile.value = true;
    profileErrors.value = {};
    try {
        const { data } = await profileApi.update(profileForm);
        auth.user = data.data;
        localStorage.setItem('auth_user', JSON.stringify(auth.user));
        toast.success('Profile updated successfully.');
    } catch (error) {
        if (error.response?.status === 422) {
            profileErrors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        savingProfile.value = false;
    }
}

const avatarInput = ref(null);
const uploadingAvatar = ref(false);

function triggerAvatarUpload() {
    avatarInput.value?.click();
}

async function onAvatarSelected(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    uploadingAvatar.value = true;
    try {
        const { data } = await profileApi.updateAvatar(file);
        auth.user = data.data;
        localStorage.setItem('auth_user', JSON.stringify(auth.user));
        toast.success('Avatar updated successfully.');
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to upload avatar.');
    } finally {
        uploadingAvatar.value = false;
        event.target.value = '';
    }
}

const passwordForm = reactive({ current_password: '', new_password: '', new_password_confirmation: '' });
const passwordErrors = ref({});
const savingPassword = ref(false);

async function submitPassword() {
    passwordErrors.value = {};
    if (passwordForm.new_password !== passwordForm.new_password_confirmation) {
        passwordErrors.value = { new_password_confirmation: ['Passwords do not match.'] };
        return;
    }

    savingPassword.value = true;
    try {
        await profileApi.updatePassword(passwordForm);
        toast.success('Password changed successfully.');
        Object.assign(passwordForm, { current_password: '', new_password: '', new_password_confirmation: '' });
    } catch (error) {
        if (error.response?.status === 422) {
            passwordErrors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        savingPassword.value = false;
    }
}
</script>

<template>
    <AppLayout>
        <h1 class="text-lg font-semibold text-slate-900 mb-4">Profile</h1>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="bg-white border border-slate-200 rounded-lg p-6 text-center">
                <div class="relative inline-block">
                    <div class="h-24 w-24 rounded-full bg-slate-200 flex items-center justify-center text-slate-600 text-2xl font-semibold overflow-hidden mx-auto">
                        <img v-if="auth.user?.avatar" :src="auth.user.avatar" class="h-full w-full object-cover" alt="" />
                        <span v-else>{{ auth.user?.name?.charAt(0)?.toUpperCase() || '?' }}</span>
                    </div>
                    <button
                        type="button"
                        :disabled="uploadingAvatar"
                        class="absolute bottom-0 right-0 h-8 w-8 rounded-full bg-primary-600 text-onbrand flex items-center justify-center text-xs hover:bg-primary-700 disabled:opacity-60"
                        @click="triggerAvatarUpload"
                    >
                        {{ uploadingAvatar ? '…' : '✎' }}
                    </button>
                    <input ref="avatarInput" type="file" accept="image/*" class="hidden" @change="onAvatarSelected" />
                </div>
                <p class="mt-4 font-semibold text-slate-900">{{ auth.user?.name }}</p>
                <p class="text-sm text-slate-500">{{ auth.user?.email }}</p>
                <div class="mt-3 flex items-center justify-center gap-2">
                    <StatusBadge :status="auth.user?.role?.slug" />
                    <StatusBadge :status="auth.user?.status?.slug" />
                </div>
                <p class="mt-3 text-xs text-slate-400">Member since {{ formatDate(auth.user?.created_at) }}</p>
            </div>

            <div class="lg:col-span-2 space-y-6">
                <div class="bg-white border border-slate-200 rounded-lg p-6">
                    <h2 class="text-sm font-semibold text-slate-700 mb-4">Account Information</h2>
                    <form class="space-y-4" @submit.prevent="submitProfile">
                        <div>
                            <label class="block text-sm font-medium text-slate-700 mb-1">Name</label>
                            <input v-model="profileForm.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                            <p v-if="profileErrors.name" class="mt-1 text-xs text-rose-600">{{ profileErrors.name[0] }}</p>
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
                            <input v-model="profileForm.email" type="email" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                            <p v-if="profileErrors.email" class="mt-1 text-xs text-rose-600">{{ profileErrors.email[0] }}</p>
                        </div>
                        <div class="flex justify-end">
                            <button type="submit" :disabled="savingProfile" class="px-4 py-2 text-sm rounded-md bg-primary-600 text-onbrand hover:bg-primary-700 disabled:opacity-60">
                                {{ savingProfile ? 'Saving…' : 'Save Changes' }}
                            </button>
                        </div>
                    </form>
                </div>

                <div class="bg-white border border-slate-200 rounded-lg p-6">
                    <h2 class="text-sm font-semibold text-slate-700 mb-4">Change Password</h2>
                    <form class="space-y-4" @submit.prevent="submitPassword">
                        <div>
                            <label class="block text-sm font-medium text-slate-700 mb-1">Current Password</label>
                            <input v-model="passwordForm.current_password" type="password" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                            <p v-if="passwordErrors.current_password" class="mt-1 text-xs text-rose-600">{{ passwordErrors.current_password[0] }}</p>
                        </div>
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <div>
                                <label class="block text-sm font-medium text-slate-700 mb-1">New Password</label>
                                <input v-model="passwordForm.new_password" type="password" required minlength="8" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                                <p v-if="passwordErrors.new_password" class="mt-1 text-xs text-rose-600">{{ passwordErrors.new_password[0] }}</p>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-slate-700 mb-1">Confirm New Password</label>
                                <input v-model="passwordForm.new_password_confirmation" type="password" required minlength="8" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                                <p v-if="passwordErrors.new_password_confirmation" class="mt-1 text-xs text-rose-600">{{ passwordErrors.new_password_confirmation[0] }}</p>
                            </div>
                        </div>
                        <div class="flex justify-end">
                            <button type="submit" :disabled="savingPassword" class="px-4 py-2 text-sm rounded-md bg-primary-600 text-onbrand hover:bg-primary-700 disabled:opacity-60">
                                {{ savingPassword ? 'Saving…' : 'Change Password' }}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </AppLayout>
</template>
