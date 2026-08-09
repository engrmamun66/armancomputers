<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Arman Computers</title>
        <link rel="icon" type="image/png" href="/favicon.png">
        <script>
            (function () {
                var mode = localStorage.getItem('theme-mode') || 'auto';
                document.documentElement.style.colorScheme = mode === 'auto' ? 'light dark' : mode;
            })();
        </script>
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="antialiased">
        <div id="app"></div>
    </body>
</html>
