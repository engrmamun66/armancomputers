<template>
    <div class="min-h-screen bg-slate-50 flex flex-col items-center justify-center px-4">
        <div class="mb-6 flex items-center gap-2">
            <div class="h-10 w-10 rounded-md bg-blue-600 text-white flex items-center justify-center font-bold">AC</div>
            <span class="font-semibold text-slate-900 text-lg">Arman Computers</span>
        </div>
        <div class="w-full max-w-sm bg-white border border-slate-200 rounded-lg shadow-sm p-6">
            <slot />
        </div>
        <p class="mt-6 text-xs text-slate-400">&copy; {{ new Date().getFullYear() }} Arman Computers. All rights reserved.</p>
    </div>
</template>
