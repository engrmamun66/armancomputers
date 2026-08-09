<script setup>
import AppLayout from '@/layouts/AppLayout.vue';
import { COMPANY } from '@/utils/company';

const SECTIONS = [
    {
        title: 'Information We Collect',
        body: 'We collect information you provide directly to us, such as your name, email address, and phone number when you create an account or are added as a user, customer, or supplier record. We also collect operational data generated through your use of the system, including product, stock, and transaction records.',
    },
    {
        title: 'How We Use Information',
        body: 'Information is used to operate and maintain the stock management system, process stock in/out transactions and invoices, manage user accounts and permissions, and provide customer support. We do not sell or rent personal information to third parties.',
    },
    {
        title: 'Data Security',
        body: 'We apply reasonable administrative and technical safeguards to protect data stored in this system, including password hashing, authenticated API access, and role-based access controls. No method of electronic storage is 100% secure, and we cannot guarantee absolute security.',
    },
    {
        title: 'Cookies',
        body: 'This application may use local browser storage to keep you signed in and remember basic preferences. We do not use cookies for third-party advertising or cross-site tracking.',
    },
    {
        title: 'Third-Party Services',
        body: 'This application does not share your data with third-party services except where required to operate core functionality (e.g., hosting infrastructure). Any such providers are expected to maintain appropriate confidentiality and security standards.',
    },
    {
        title: 'User Rights',
        body: 'You may request access to, correction of, or deletion of your personal information held within this system, subject to legitimate business and record-keeping requirements (such as retaining historical transaction records). Contact your system administrator to make such a request.',
    },
];
</script>

<template>
    <AppLayout>
        <h1 class="text-lg font-semibold text-slate-900 mb-1">Privacy Policy</h1>
        <p class="text-sm text-slate-500 mb-6">Last updated: this policy applies to your use of the {{ COMPANY.name }} stock management system.</p>

        <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-3xl space-y-6">
            <section v-for="section in SECTIONS" :key="section.title">
                <h2 class="text-sm font-semibold text-slate-800 mb-2">{{ section.title }}</h2>
                <p class="text-sm text-slate-600 leading-relaxed">{{ section.body }}</p>
            </section>

            <section>
                <h2 class="text-sm font-semibold text-slate-800 mb-2">Contact Information</h2>
                <p class="text-sm text-slate-600 leading-relaxed">
                    Questions about this policy can be directed to {{ COMPANY.name }} at {{ COMPANY.email }} or {{ COMPANY.phone }}.
                </p>
            </section>
        </div>
    </AppLayout>
</template>
