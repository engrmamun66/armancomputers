import api from './api';

export default {
    list(params) {
        return api.get('/stock-ins', { params });
    },
    get(id) {
        return api.get(`/stock-ins/${id}`);
    },
    create(payload) {
        return api.post('/stock-ins', payload);
    },
    update(id, payload) {
        return api.put(`/stock-ins/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/stock-ins/${id}`);
    },
};
