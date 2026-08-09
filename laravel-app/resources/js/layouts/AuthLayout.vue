<script setup>
import logoHorizontal from '@/../images/logo-horizontal.png';
</script>

<template>
    <div class="min-h-screen bg-slate-50 flex flex-col items-center justify-center px-4">
        <div class="mb-6">
            <img :src="logoHorizontal" alt="Arman Computers" class="h-14 object-contain" />
        </div>
        <div class="w-full max-w-sm bg-white border border-slate-200 rounded-lg shadow-sm p-6">
            <slot />
        </div>
        <p class="mt-6 text-xs text-slate-400">&copy; {{ new Date().getFullYear() }} Arman Computers. All rights reserved.</p>
    </div>
</template>
