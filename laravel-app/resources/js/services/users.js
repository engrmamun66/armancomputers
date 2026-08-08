import api from './api';

export default {
    list(params) {
        return api.get('/users', { params });
    },
    create(payload) {
        return api.post('/users', payload);
    },
    update(id, payload) {
        return api.put(`/users/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/users/${id}`);
    },
    resetPassword(id, payload) {
        return api.post(`/users/${id}/reset-password`, payload);
    },
};
