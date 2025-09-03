import {createRouter, createWebHistory} from 'vue-router'

const routes = [
    {
        path: '/',
        name: 'home',
        component: () => import(/* webpackChunkName: "about" */ '../App.vue')
    },
    // {
    //     path: '/about',
    //     name: 'about',
    //     component: () => import(/* webpackChunkName: "about" */ '../views/AboutView.vue'),
    //     meta: {requiresAuth: false} // 👈 обязательно!
    // },
    {
        path: '/maps',
        name: 'DrawMap',
        component: () => import(/* webpackChunkName: "about" */ '../views/DrawMap.vue'),
        meta: {requiresAuth: false} // 👈 обязательно!
    },
]

const mainRouter = createRouter({
    history: createWebHistory(process.env.BASE_URL),
    routes
})

export default mainRouter
