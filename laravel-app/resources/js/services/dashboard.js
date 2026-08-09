import api from './api';

export default {
    get(params) {
        return api.get('/dashboard', { params });
    },
};
