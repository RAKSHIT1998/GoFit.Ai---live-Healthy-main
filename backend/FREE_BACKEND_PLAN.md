## Free Backend Plan

This backend can run at `$0/month` on Render for a low-traffic hobby app, but only with tradeoffs:

- The service will sleep after inactivity.
- The first request after sleep can take around a minute.
- Real-time/social features will be less reliable than on a paid always-on instance.

### What to change

1. Set the Render web service to the `free` instance type.
2. Do not provision Render Redis unless you actually need it.
3. Keep MongoDB on a free tier if your current database usage fits.
4. Remove AWS S3 credentials if you want to avoid storage charges too.

### Important app/runtime implications

- Login, signup, and other first-hit API calls need longer client timeouts.
- WebSocket-based features may reconnect after the backend wakes up.
- The backend already works without Redis when Redis is not configured.
- Progress photos can still save without S3, but they fall back to storing image data in MongoDB, which should only be used for low volume.

### Recommended no-cost setup

- Render web service: Free
- MongoDB Atlas: Free cluster
- Redis: Disabled
- S3: Disabled unless you really need cloud photo storage

### When to stop using the free setup

Move back to a paid always-on backend when any of these become true:

- users complain about slow first loads
- chat/realtime becomes a core feature
- photo/progress storage grows
- OpenAI usage becomes meaningful enough that backend hosting is no longer the main cost
