import api from './api';

export default {
    list(params) {
        return api.get('/invoices', { params });
    },
    get(id) {
        return api.get(`/invoices/${id}`);
    },
};
