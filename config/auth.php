<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Authentication Defaults
    |--------------------------------------------------------------------------
    |
    | This option controls the default authentication "guard" and password
    | reset options for your application.
    |
    */
    'defaults' => [
        'guard' => 'web',
        'passwords' => 'users',
    ],

    /*
    |--------------------------------------------------------------------------
    | Authentication Guards
    |--------------------------------------------------------------------------
    |
    | The `api` guard uses the `jwt` driver registered by the Golem15.User
    | plugin (JwtAuthGuardServiceProvider::boot -> auth()->extend('jwt', ...)).
    | The jwt.auth middleware calls auth()->shouldUse('api'), so frontend API
    | handlers resolve the JWT user via auth()->user(). This MUST be `jwt`,
    | not `token` (mirrors MeAreasApiTest::setUp, the known-good config).
    |
    */
    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
        'api' => [
            'driver' => 'jwt',
            'provider' => 'users',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | User Providers
    |--------------------------------------------------------------------------
    */
    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => Golem15\User\Models\User::class,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Resetting Passwords
    |--------------------------------------------------------------------------
    */
    'passwords' => [
        'users' => [
            'provider' => 'users',
            'email' => 'auth.emails.password',
            'table' => 'password_resets',
            'expire' => 60,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Backend authentication throttling (WinterCMS)
    |--------------------------------------------------------------------------
    |
    | Preserved from the original superproject config/auth.php.
    |
    */
    'throttle' => [
        'enabled' => true,
        'attemptLimit' => 5,
        'suspensionTime' => 15,
    ],
];
