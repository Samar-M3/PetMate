# Shop catalogue seed

Run from `backend/` after optionally setting these environment variables:

- `SHOP_SEED_OWNER_USER_ID`: an existing `users.id`. If omitted, the oldest existing user is used for the local demo store. The script creates an approved store only if the selected user does not already have one; it refuses to change an existing store's approval status.
- `SHOP_SEED_CLOUDINARY_IMAGES`: an optional JSON array of at least two Cloudinary URL/public-ID objects, for example `[ {"url":"https://res.cloudinary.com/YOUR_CLOUD/image/upload/v1/pets/a.jpg","publicId":"pets/a"}, {"url":"https://res.cloudinary.com/YOUR_CLOUD/image/upload/v1/pets/b.jpg","publicId":"pets/b"} ]`. When omitted, the demo products have no image records and the app displays its built-in pet icon fallback. No random or placeholder URLs are inserted.

Then run:

```sh
npm run seed:shop
```

The seed is safe to run more than once. It does not use remote stock photos or change an existing store's approval state. It seeds seven categories and 21 products. If Cloudinary image pairs are supplied, it uses them for product and category images.
