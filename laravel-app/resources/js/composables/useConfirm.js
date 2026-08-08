import { reactive } from 'vue';

const state = reactive({
    visible: false,
    title: '',
    message: '',
    confirmText: 'Confirm',
    cancelText: 'Cancel',
    danger: true,
    resolve: null,
});

function confirm(options = {}) {
    state.title = options.title || 'Are you sure?';
    state.message = options.message || 'This action cannot be undone.';
    state.confirmText = options.confirmText || 'Confirm';
    state.cancelText = options.cancelText || 'Cancel';
    state.danger = options.danger !== false;
    state.visible = true;

    return new Promise((resolve) => {
        state.resolve = resolve;
    });
}

function respond(result) {
    state.visible = false;
    state.resolve?.(result);
    state.resolve = null;
}

export function useConfirm() {
    return { state, confirm, respond };
}
