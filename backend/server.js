const fastify = require('fastify')({ logger: true });

// Register CORS for seamless mobile and web client communication
fastify.register(require('@fastify/cors'), {
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
});

// In-memory food catalog store
const foods = [
  {
    id: 'food_1',
    name: 'Fresh Haas Avocado',
    description: 'Organic, perfectly ripe California Haas avocado. Nutrient-dense, creamy texture, rich in healthy fats and potassium. Served sliced or whole.',
    price: 4.99,
    category: 'Healthy',
    thumbnailUrl: 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?auto=format&fit=crop&w=800&q=80',
    modelUrl: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Avocado/glTF-Binary/Avocado.glb',
    modelUrlIos: null,
    realWorldSizeCm: { width: 7.5, depth: 7.5, height: 11.0 },
    isAvailable: true,
    pairsWith: ['food_6', 'food_3'],
    version: 1,
  },
  {
    id: 'food_2',
    name: 'Artisan Margherita Pizza',
    description: 'Authentic wood-fired Neapolitan pizza crafted with San Marzano tomatoes, fresh buffalo mozzarella, fragrant basil leaves, and cold-pressed extra virgin olive oil.',
    price: 16.75,
    category: 'Pizza',
    thumbnailUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80',
    modelUrl: 'https://raw.githubusercontent.com/needle-engine/ar-restaurant-example/main/Website/static/assets/pizza.glb',
    modelUrlIos: null,
    realWorldSizeCm: { width: 28.0, depth: 28.0, height: 3.0 },
    isAvailable: true,
    pairsWith: ['food_6', 'food_5', 'food_4'],
    version: 1,
  },
  {
    id: 'food_3',
    name: 'Sashimi Nigiri Platter',
    description: 'Chef selection of premium sashimi-grade Atlantic salmon and bluefin tuna delicately draped over hand-pressed seasoned sushi rice with wasabi.',
    price: 18.50,
    category: 'Asian',
    thumbnailUrl: 'https://images.unsplash.com/photo-1611143669185-af224c5e3252?auto=format&fit=crop&w=800&q=80',
    modelUrl: 'https://raw.githubusercontent.com/needle-engine/ar-restaurant-example/main/Website/static/assets/nigiri.glb',
    modelUrlIos: null,
    realWorldSizeCm: { width: 18.0, depth: 12.0, height: 4.0 },
    isAvailable: true,
    pairsWith: ['food_6', 'food_1'],
    version: 1,
  },
  {
    id: 'food_4',
    name: 'Belgian Chocolate Marshmallow',
    description: 'Decadent Valrhona dark chocolate mousse layered with toasted fluffy marshmallows, dusted with cocoa powder and drizzled with warm cocoa ganache.',
    price: 12.99,
    category: 'Desserts',
    thumbnailUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=800&q=80',
    modelUrl: 'https://raw.githubusercontent.com/needle-engine/ar-restaurant-example/main/Website/static/assets/chocolateMarshmallow.glb',
    modelUrlIos: null,
    realWorldSizeCm: { width: 14.0, depth: 14.0, height: 8.5 },
    isAvailable: true,
    pairsWith: ['food_5', 'food_6'],
    version: 1,
  },
  {
    id: 'food_5',
    name: 'Barista Specialty Espresso Machine',
    description: 'Precision single-origin Ethiopian extraction station. Experience the art of hand-pulled espresso with notes of bergamot, jasmine, and dark honey.',
    price: 6.50,
    category: 'Beverages',
    thumbnailUrl: 'https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?auto=format&fit=crop&w=800&q=80',
    modelUrl: 'https://modelviewer.dev/shared-assets/models/coffeemat.glb',
    modelUrlIos: null,
    realWorldSizeCm: { width: 22.0, depth: 18.0, height: 32.0 },
    isAvailable: true,
    pairsWith: ['food_4', 'food_2'],
    version: 1,
  },
  {
    id: 'food_6',
    name: 'Alpine Botanical Spring Infusion',
    description: 'Pure alpine mineral water infused with hand-picked mint, cucumber ribbons, and Meyer lemon zest. Served chilled in an eco-glass decanter.',
    price: 5.25,
    category: 'Beverages',
    thumbnailUrl: 'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=800&q=80',
    modelUrl: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/WaterBottle/glTF-Binary/WaterBottle.glb',
    modelUrlIos: null,
    realWorldSizeCm: { width: 7.5, depth: 7.5, height: 26.0 },
    isAvailable: true,
    pairsWith: ['food_2', 'food_3', 'food_1'],
    version: 1,
  },
];

// In-memory orders store
const orders = [];

// =============================================================================
// API Endpoints
// =============================================================================

// Root Health Check & API Directory
fastify.get('/', async (request, reply) => {
  return {
    service: 'Food AR Restaurant Backend API',
    status: 'online',
    version: '1.0.0',
    endpoints: {
      getFoods: 'GET /foods',
      getFoodById: 'GET /foods/:id',
      postOrder: 'POST /orders',
      getOrders: 'GET /orders',
    },
  };
});

// 1. GET /foods - Retrieve all dishes
fastify.get('/foods', async (request, reply) => {
  return foods;
});

// 2. GET /foods/:id - Retrieve specific dish by ID
fastify.get('/foods/:id', async (request, reply) => {
  const { id } = request.params;
  const food = foods.find((f) => f.id === id);

  if (!food) {
    reply.status(404);
    return { error: 'Dish not found', id };
  }

  return food;
});

// 3. POST /orders - Submit kitchen order
fastify.post('/orders', async (request, reply) => {
  const body = request.body || {};
  const items = Array.isArray(body.items) ? body.items : [];

  if (items.length === 0) {
    reply.status(400);
    return { error: 'Order must contain at least one item' };
  }

  const orderId = `ORD-${Date.now().toString().slice(-6)}`;
  const tableNumber = body.tableNumber || 1;
  const total = Number(body.total) || 0;
  const subtotal = Number(body.subtotal) || 0;
  const tax = Number(body.tax) || 0;

  const order = {
    orderId,
    tableNumber,
    items,
    subtotal,
    tax,
    total,
    status: 'received',
    estimatedPrepMinutes: 15 + Math.floor(Math.random() * 8),
    specialInstructions: body.specialInstructions || '',
    createdAt: new Date().toISOString(),
  };

  orders.push(order);

  reply.status(201);
  return {
    success: true,
    message: 'Order dispatched to kitchen successfully',
    ...order,
  };
});

// Optional: GET /orders - List all submitted orders (useful for testing/kitchen view)
fastify.get('/orders', async (request, reply) => {
  return {
    count: orders.length,
    orders,
  };
});

// Start Server
const start = async () => {
  try {
    const port = process.env.PORT || 3000;
    const host = process.env.HOST || '0.0.0.0';
    await fastify.listen({ port, host });
    console.log(`🚀 Food AR Fastify Backend running at http://${host}:${port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
