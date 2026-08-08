import { reactive } from 'vue';

const state = reactive({ toasts: [] });
let nextId = 0;

function push(type, message, timeout = 4000) {
    const id = ++nextId;
    state.toasts.push({ id, type, message });
    setTimeout(() => remove(id), timeout);
}

function remove(id) {
    const index = state.toasts.findIndex((toast) => toast.id === id);
    if (index !== -1) state.toasts.splice(index, 1);
}

export function useToast() {
    return {
        toasts: state.toasts,
        success: (message) => push('success', message),
        error: (message) => push('error', message),
        info: (message) => push('info', message),
        remove,
    };
}
