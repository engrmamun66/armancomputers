<script setup>
import { reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import AuthLayout from '@/layouts/AuthLayout.vue';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();

const form = reactive({ email: '', password: '' });
const errors = ref({});
const generalError = ref('');
const loading = ref(false);

async function submit() {
    errors.value = {};
    generalError.value = '';
    loading.value = true;
    try {
        await auth.login(form);
        router.push(route.query.redirect || { name: 'dashboard' });
    } catch (error) {
        if (error.response?.status === 422) {
            errors.value = error.response.data.errors || {};
        } else if (error.response?.status === 401) {
            generalError.value = error.response.data.message || 'Invalid email or password.';
        } else {
            generalError.value = 'Something went wrong. Please try again.';
        }
    } finally {
        loading.value = false;
    }
}
</script>

<template>
    <AuthLayout>
        <h1 class="text-lg font-semibold text-slate-900 mb-1">Sign in</h1>
        <p class="text-sm text-slate-500 mb-6">Welcome back. Please enter your details.</p>

        <div v-if="generalError" class="mb-4 rounded-md bg-rose-50 border border-rose-200 text-rose-700 text-sm px-3 py-2">
            {{ generalError }}
        </div>

        <form class="space-y-4" @submit.prevent="submit">
            <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
                <input
                    v-model="form.email"
                    type="email"
                    required
                    autocomplete="username"
                    class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                    :class="errors.email ? 'border-rose-400' : ''"
                />
                <p v-if="errors.email" class="mt-1 text-xs text-rose-600">{{ errors.email[0] }}</p>
            </div>
            <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Password</label>
                <input
                    v-model="form.password"
                    type="password"
                    required
                    autocomplete="current-password"
                    class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                    :class="errors.password ? 'border-rose-400' : ''"
                />
                <p v-if="errors.password" class="mt-1 text-xs text-rose-600">{{ errors.password[0] }}</p>
            </div>
            <button
                type="submit"
                :disabled="loading"
                class="w-full py-2.5 rounded-md bg-accent-solid text-on-accent-solid text-sm font-medium hover:bg-accent-solid-hover disabled:opacity-60"
            >
                {{ loading ? 'Signing in…' : 'Sign in' }}
            </button>
        </form>
    </AuthLayout>
</template>
