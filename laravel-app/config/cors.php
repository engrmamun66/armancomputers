<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Bearer-token auth (tymon/jwt-auth), no cookies involved, so
    | supports_credentials stays false. Origins listed below cover the web
    | SPA dev server plus every way the Flutter mobile app reaches this API
    | (see mobile-app/.env.example): emulator (10.0.2.2), Chrome (127.0.0.1),
    | and a real device over LAN.
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => [
        'http://127.0.0.1:7878',
        'http://localhost:7878',
        'http://10.0.2.2:7878',
        'http://192.168.68.100:7878',
    ],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
