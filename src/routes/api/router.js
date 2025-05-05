const express = require('express');
const router = express.Router();

// Modular routers
const itemRouter = require('./api/item.router');
// if we create later product.router, user.router, etc., import them here
// const productRouter = require('./api/product.router');
// const userRouter = require('./api/user.router');
// const authRouter = require('./api/auth.router');
// const orderRouter = require('./api/order.router');
// const reviewRouter = require('./api/review.router');
// const categoryRouter = require('./api/category.router');
// const cartRouter = require('./api/cart.router');
// const paymentRouter = require('./api/payment.router');
// const wishlistRouter = require('./api/wishlist.router');
// const notificationRouter = require('./api/notification.router');
// const addressRouter = require('./api/address.router');
// const searchRouter = require('./api/search.router');
// const chatRouter = require('./api/chat.router');
// const messageRouter = require('./api/message.router');
// const reportRouter = require('./api/report.router');
// const settingRouter = require('./api/setting.router');
// const subscriptionRouter = require('./api/subscription.router');
// const wishlistRouter = require('./api/wishlist.router');
// const notificationRouter = require('./api/notification.router');
// const addressRouter = require('./api/address.router');


// Base routes
router.use('/items', itemRouter);

// If more resources are created, add them here:
// router.use('/products', productRouter);
// router.use('/users', userRouter);

module.exports = router;
