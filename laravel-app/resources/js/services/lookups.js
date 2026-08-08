import api from './api';

export default {
    roles() {
        return api.get('/roles');
    },
    statuses(type) {
        return api.get('/statuses', { params: { type } });
    },
};
