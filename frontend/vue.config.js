const {defineConfig} = require('@vue/cli-service')
module.exports = defineConfig({
    transpileDependencies: [],
    configureWebpack: {devtool: 'source-map'},

    publicPath: '/night/',
    devServer: {
        proxy: {
            '/night/api': { // Добавляем /auth к API
                target: 'http://localhost:5001',
                // target: 'http://localhost:80',
                changeOrigin: true,
                secure: false,
                pathRewrite: {'^/night/api': '/api'} // Убираем /auth перед отправкой на сервер
            }
        }
    }
})
