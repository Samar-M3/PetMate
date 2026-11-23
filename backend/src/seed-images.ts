import prisma from "./config/db.ts";

const categoryImages: Record<string, string> = {
  "Pet Food": "https://images.unsplash.com/photo-1589924691995-400dc9ecc119?w=600&auto=format&fit=crop&q=80",
  "Dog Food": "https://images.unsplash.com/photo-1568640347023-a616a30bc3bd?w=600&auto=format&fit=crop&q=80",
  "Toys": "https://images.unsplash.com/photo-1576201836106-db1758fd1c97?w=600&auto=format&fit=crop&q=80",
  "Accessories": "https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=600&auto=format&fit=crop&q=80",
  "Grooming": "https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=600&auto=format&fit=crop&q=80",
  "Healthcare": "https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?w=600&auto=format&fit=crop&q=80",
  "Bedding": "https://images.unsplash.com/photo-1541599540903-216a46ca1dc0?w=600&auto=format&fit=crop&q=80",
};

const productImages: Record<string, string[]> = {
  "Everyday Dog Kibble": [
    "https://images.unsplash.com/photo-1589924691995-400dc9ecc119?w=800&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1568640347023-a616a30bc3bd?w=800&auto=format&fit=crop&q=80",
  ],
  "Puppy Growth Formula": [
    "https://images.unsplash.com/photo-1568640347023-a616a30bc3bd?w=800&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1589924691995-400dc9ecc119?w=800&auto=format&fit=crop&q=80",
  ],
  "Sensitive Stomach Recipe": [
    "https://images.unsplash.com/photo-1585846416120-3a7354ed7d39?w=800&auto=format&fit=crop&q=80",
  ],
  "Grain Free Adult Meal": [
    "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=800&auto=format&fit=crop&q=80",
  ],
  "Cat Feast Pouches": [
    "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800&auto=format&fit=crop&q=80",
  ],
  "Tuna Crunch Treats": [
    "https://images.unsplash.com/photo-1574158622682-e40e69881006?w=800&auto=format&fit=crop&q=80",
  ],
  "Rope Tug Toy": [
    "https://images.unsplash.com/photo-1608848461950-0fe51dfc41cb?w=800&auto=format&fit=crop&q=80",
  ],
  "Feather Chase Wand": [
    "https://images.unsplash.com/photo-1545249390-6bdfa286032f?w=800&auto=format&fit=crop&q=80",
  ],
  "Treat Puzzle Board": [
    "https://images.unsplash.com/photo-1535294435445-d7249524ef2e?w=800&auto=format&fit=crop&q=80",
  ],
  "Soft Chew Ball": [
    "https://images.unsplash.com/photo-1576201836106-db1758fd1c97?w=800&auto=format&fit=crop&q=80",
  ],
  "Adjustable Walking Harness": [
    "https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=800&auto=format&fit=crop&q=80",
  ],
  "Reflective Lead": [
    "https://images.unsplash.com/photo-1534361960057-19889db9621e?w=800&auto=format&fit=crop&q=80",
  ],
  "Everyday Collar": [
    "https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=800&auto=format&fit=crop&q=80",
  ],
  "Gentle Coat Shampoo": [
    "https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=800&auto=format&fit=crop&q=80",
  ],
  "Soft Slicker Brush": [
    "https://images.unsplash.com/photo-1522276498395-f4f68f7f8454?w=800&auto=format&fit=crop&q=80",
  ],
  "Nail Care Clippers": [
    "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=800&auto=format&fit=crop&q=80",
  ],
  "Daily Dental Chews": [
    "https://images.unsplash.com/photo-1541364983171-a8ba01e95cfc?w=800&auto=format&fit=crop&q=80",
  ],
  "Paw Balm": [
    "https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?w=800&auto=format&fit=crop&q=80",
  ],
  "Cushioned Nap Mat": [
    "https://images.unsplash.com/photo-1541599540903-216a46ca1dc0?w=800&auto=format&fit=crop&q=80",
  ],
  "Cooling Rest Pad": [
    "https://images.unsplash.com/photo-1591946614720-90a587da4a36?w=800&auto=format&fit=crop&q=80",
  ],
  "Archived Travel Bowl": [
    "https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?w=800&auto=format&fit=crop&q=80",
  ],
};

async function seed() {
  console.log("Seeding category images...");
  for (const [name, imageUrl] of Object.entries(categoryImages)) {
    await prisma.category.updateMany({
      where: { name },
      data: { imageUrl },
    });
  }

  console.log("Seeding product images...");
  for (const [name, urls] of Object.entries(productImages)) {
    const product = await prisma.product.findFirst({ where: { name } });
    if (!product) continue;

    // Delete existing product images
    await prisma.productImage.deleteMany({ where: { productId: product.id } });

    // Add new images
    for (let i = 0; i < urls.length; i++) {
      await prisma.productImage.create({
        data: {
          productId: product.id,
          imageUrl: urls[i],
          cloudinaryPublicId: `seed-${product.slug}-${i}`,
          displayOrder: i,
        },
      });
    }
  }

  console.log("Seed complete!");
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
