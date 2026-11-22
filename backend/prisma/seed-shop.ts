import "dotenv/config";
import prisma from "../src/config/db.ts";

type SeedImage = { url: string; publicId: string };

const imageInput = process.env.SHOP_SEED_CLOUDINARY_IMAGES;
const ownerId = process.env.SHOP_SEED_OWNER_USER_ID;

let images: SeedImage[] = [];
if (imageInput) {
  try {
    images = JSON.parse(imageInput) as SeedImage[];
  } catch {
    throw new Error("SHOP_SEED_CLOUDINARY_IMAGES must be valid JSON.");
  }
  if (
    !Array.isArray(images) ||
    images.length < 2 ||
    images.some((image) => !image.url?.startsWith("https://res.cloudinary.com/") || !image.publicId)
  ) {
    throw new Error("Provide at least two Cloudinary images, each with an https://res.cloudinary.com URL and publicId.");
  }
} else {
  console.warn("No Shop seed images supplied; products will use the app's built-in image fallback.");
}

const categorySeeds = [
  { name: "Pet Food", slug: "pet-food" },
  { name: "Dog Food", slug: "dog-food", parent: "pet-food" },
  { name: "Toys", slug: "toys" },
  { name: "Accessories", slug: "accessories" },
  { name: "Grooming", slug: "grooming" },
  { name: "Healthcare", slug: "healthcare" },
  { name: "Bedding", slug: "bedding" },
];

const productSeeds = [
  ["Everyday Dog Kibble", "everyday-dog-kibble", "dog-food", "Paw Pantry", 1450, 1290, 35, "ACTIVE", true, false],
  ["Puppy Growth Formula", "puppy-growth-formula", "dog-food", "Paw Pantry", 1850, null, 22, "ACTIVE", true, true],
  ["Sensitive Stomach Recipe", "sensitive-stomach-recipe", "dog-food", "Kind Bowl", 2200, 1990, 14, "ACTIVE", false, false],
  ["Grain Free Adult Meal", "grain-free-adult-meal", "pet-food", "Kind Bowl", 2600, null, 10, "ACTIVE", false, true],
  ["Cat Feast Pouches", "cat-feast-pouches", "pet-food", "Meow Market", 850, 790, 42, "ACTIVE", true, false],
  ["Tuna Crunch Treats", "tuna-crunch-treats", "pet-food", "Meow Market", 420, null, 50, "ACTIVE", false, false],
  ["Rope Tug Toy", "rope-tug-toy", "toys", "Playful Paws", 550, null, 30, "ACTIVE", true, false],
  ["Feather Chase Wand", "feather-chase-wand", "toys", "Playful Paws", 380, 320, 25, "ACTIVE", false, false],
  ["Treat Puzzle Board", "treat-puzzle-board", "toys", "Clever Critter", 1250, null, 12, "ACTIVE", true, false],
  ["Soft Chew Ball", "soft-chew-ball", "toys", "Playful Paws", 490, null, 0, "OUT_OF_STOCK", false, false],
  ["Adjustable Walking Harness", "adjustable-walking-harness", "accessories", "Trail Tails", 1750, 1590, 18, "ACTIVE", true, true],
  ["Reflective Lead", "reflective-lead", "accessories", "Trail Tails", 900, null, 31, "ACTIVE", false, false],
  ["Everyday Collar", "everyday-collar", "accessories", "Trail Tails", 650, null, 45, "ACTIVE", false, true],
  ["Gentle Coat Shampoo", "gentle-coat-shampoo", "grooming", "Fresh Fur", 720, 650, 26, "ACTIVE", true, false],
  ["Soft Slicker Brush", "soft-slicker-brush", "grooming", "Fresh Fur", 580, null, 19, "ACTIVE", false, false],
  ["Nail Care Clippers", "nail-care-clippers", "grooming", "Fresh Fur", 800, null, 11, "ACTIVE", false, false],
  ["Daily Dental Chews", "daily-dental-chews", "healthcare", "Healthy Hound", 950, null, 28, "ACTIVE", true, false],
  ["Paw Balm", "paw-balm", "healthcare", "Healthy Hound", 600, 540, 32, "ACTIVE", false, false],
  ["Cushioned Nap Mat", "cushioned-nap-mat", "bedding", "Cozy Critter", 2100, null, 9, "ACTIVE", true, true],
  ["Cooling Rest Pad", "cooling-rest-pad", "bedding", "Cozy Critter", 1650, null, 0, "DRAFT", false, false],
  ["Archived Travel Bowl", "archived-travel-bowl", "accessories", "Trail Tails", 750, null, 0, "INACTIVE", false, false],
] as const;

const main = async () => {
  const owner = ownerId
    ? await prisma.user.findUnique({ where: { id: ownerId } })
    : await prisma.user.findFirst({ orderBy: { createdAt: "asc" } });
  if (!owner) throw new Error("No existing PetMate user is available to own the demo store.");
  if (!ownerId) console.log("Using the oldest existing PetMate user as the demo store owner.");

  let store = await prisma.store.findUnique({ where: { userId: owner.id } });
  if (store && store.status !== "APPROVED") {
    throw new Error(`The selected user's store exists but is ${store.status}; refusing to change its approval status.`);
  }
  if (!store) {
    store = await prisma.store.create({
      data: {
        userId: owner.id,
        name: "PetMate Demo Store",
        slug: `petmate-demo-${owner.id.slice(0, 8)}`,
        description: "Seed catalogue store for customer Shop development.",
        status: "APPROVED",
      },
    });
  }

  const categories = new Map<string, string>();
  for (const seed of categorySeeds) {
    const parentId = seed.parent ? categories.get(seed.parent) : undefined;
    const categoryImage = images.length > 0
      ? { imageUrl: images[0].url, cloudinaryPublicId: images[0].publicId }
      : {};
    const category = await prisma.category.upsert({
      where: { slug: seed.slug },
      create: { name: seed.name, slug: seed.slug, parentId, ...categoryImage },
      update: { name: seed.name, ...(parentId ? { parentId } : {}), ...categoryImage },
    });
    categories.set(seed.slug, category.id);
  }

  for (let index = 0; index < productSeeds.length; index++) {
    const [name, slug, categorySlug, brand, basePrice, discountedPrice, stock, status, featured, hasVariants] = productSeeds[index];
    const categoryId = categories.get(categorySlug);
    if (!categoryId) throw new Error(`Missing seeded category: ${categorySlug}`);
    const existingProduct = await prisma.product.findUnique({ where: { slug }, select: { storeId: true } });
    if (existingProduct && existingProduct.storeId !== store.id) {
      throw new Error(`Seed slug ${slug} already belongs to a different store; refusing to reassign it.`);
    }
    const product = await prisma.product.upsert({
      where: { slug },
      create: {
        name,
        slug,
        brand,
        basePrice,
        discountedPrice,
        availableStock: hasVariants ? 0 : stock,
        status,
        isFeatured: featured,
        categoryId,
        storeId: store.id,
      },
      update: {
        name,
        brand,
        basePrice,
        discountedPrice,
        availableStock: hasVariants ? 0 : stock,
        status,
        isFeatured: featured,
        categoryId,
        storeId: store.id,
      },
    });

    if (images.length > 0) {
      const firstImage = images[(index * 2) % images.length];
      const secondImage = images[(index * 2 + 1) % images.length];
      await prisma.productImage.deleteMany({ where: { productId: product.id } });
      await prisma.productImage.createMany({
        data: [firstImage, secondImage].map((image, displayOrder) => ({
          productId: product.id,
          imageUrl: image.url,
          cloudinaryPublicId: image.publicId,
          displayOrder,
        })),
      });
    }

    if (hasVariants) {
      const definitions = slug === "puppy-growth-formula"
        ? [
            { optionValues: { size: "2kg" }, optionKey: "size=2kg", availableStock: 12 },
            { optionValues: { size: "5kg" }, optionKey: "size=5kg", availableStock: 10 },
          ]
        : slug === "adjustable-walking-harness"
          ? [
              { optionValues: { color: "Sage", size: "S" }, optionKey: "color=Sage|size=S", availableStock: 6 },
              { optionValues: { color: "Terracotta", size: "M" }, optionKey: "color=Terracotta|size=M", availableStock: 7 },
            ]
          : slug === "everyday-collar"
            ? [
                { optionValues: { color: "Sage", size: "Small" }, optionKey: "color=Sage|size=Small", availableStock: 20 },
                { optionValues: { color: "Blue", size: "Large" }, optionKey: "color=Blue|size=Large", availableStock: 25 },
              ]
            : [
                { optionValues: { size: "Medium" }, optionKey: "size=Medium", availableStock: 5 },
                { optionValues: { size: "Large" }, optionKey: "size=Large", availableStock: 4 },
              ];
      for (const definition of definitions) {
        await prisma.productVariant.upsert({
          where: { productId_optionKey: { productId: product.id, optionKey: definition.optionKey } },
          create: { productId: product.id, ...definition, isAvailable: true },
          update: { ...definition, isAvailable: true },
        });
      }
    }
  }

  console.log(`Seeded ${productSeeds.length} products and ${categorySeeds.length} categories into ${store.name}.`);
};

main()
  .catch((error) => {
    console.error("Shop seed failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => prisma.$disconnect());
