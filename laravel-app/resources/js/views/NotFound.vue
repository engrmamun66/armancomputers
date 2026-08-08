<script setup>
import { RouterLink } from 'vue-router';
</script>

<template>
    <div class="min-h-screen flex flex-col items-center justify-center text-center px-4">
        <p class="text-5xl font-bold text-slate-300">404</p>
        <p class="mt-2 text-slate-600">Page not found.</p>
        <RouterLink :to="{ name: 'dashboard' }" class="mt-4 text-sm font-medium text-blue-600 hover:text-blue-700">
            Back to Dashboard
        </RouterLink>
    </div>
</template>
