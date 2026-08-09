<script setup>
import { reactive, ref } from 'vue';
import AppLayout from '@/layouts/AppLayout.vue';
import { COMPANY } from '@/utils/company';
import { useToast } from '@/composables/useToast';

const toast = useToast();

const form = reactive({ name: '', email: '', subject: '', message: '' });
const sending = ref(false);

function submit() {
    sending.value = true;
    setTimeout(() => {
        sending.value = false;
        toast.success('Your message has been sent. We will get back to you soon.');
        Object.assign(form, { name: '', email: '', subject: '', message: '' });
    }, 400);
}
</script>

<template>
    <AppLayout>
        <h1 class="text-lg font-semibold text-slate-900 mb-4">Contact Us</h1>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="bg-white border border-slate-200 rounded-lg p-6 space-y-4">
                <h2 class="text-sm font-semibold text-slate-700">{{ COMPANY.name }}</h2>
                <div class="text-sm">
                    <p class="text-slate-400">Phone</p>
                    <p class="text-slate-800 font-medium">{{ COMPANY.phone }}</p>
                </div>
                <div class="text-sm">
                    <p class="text-slate-400">Email</p>
                    <p class="text-slate-800 font-medium">{{ COMPANY.email }}</p>
                </div>
                <div class="text-sm">
                    <p class="text-slate-400">Address</p>
                    <p class="text-slate-800 font-medium">{{ COMPANY.address }}</p>
                </div>
                <div class="text-sm">
                    <p class="text-slate-400">Business Hours</p>
                    <p class="text-slate-800 font-medium">{{ COMPANY.hours }}</p>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6">
                <h2 class="text-sm font-semibold text-slate-700 mb-4">Send us a message</h2>
                <form class="space-y-4" @submit.prevent="submit">
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Name</label>
                        <input v-model="form.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
                        <input v-model="form.email" type="email" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Subject</label>
                        <input v-model="form.subject" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Message</label>
                        <textarea v-model="form.message" rows="4" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"></textarea>
                    </div>
                    <div class="flex justify-end">
                        <button type="submit" :disabled="sending" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60">
                            {{ sending ? 'Sending…' : 'Send Message' }}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </AppLayout>
</template>
