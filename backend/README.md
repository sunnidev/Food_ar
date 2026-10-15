# Food AR — Fastify Backend Service

Minimal, high-performance Node.js backend built with [Fastify](https://fastify.dev/) for the Food AR Flutter application.

## Features
- **In-Memory Store**: Dish catalog populated with realistic dishes, 3D GLB model links, and pairing recommendations.
- **Order Dispatch**: Real-time kitchen orders with table assignments, timestamps, and order tracking IDs.
- **CORS Enabled**: Configured via `@fastify/cors` to allow seamless local network and mobile emulator access.

---

## Quick Start

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Run the Server
```bash
# Start server on http://localhost:3000
npm start

# Or with live auto-reload during development:
npm run dev
```

---

## API Endpoints

### 1. Get All Dishes
- **URL**: `GET /foods`
- **Response**: Array of `FoodItem` JSON objects with 3D models and dimensions.

```bash
curl http://localhost:3000/foods
```

### 2. Get Dish By ID
- **URL**: `GET /foods/:id`
- **Example**: `GET /foods/food_2`

```bash
curl http://localhost:3000/foods/food_2
```

### 3. Submit Kitchen Order
- **URL**: `POST /orders`
- **Body**:
```json
{
  "tableNumber": 4,
  "items": [
    {
      "foodId": "food_2",
      "name": "Artisan Margherita Pizza",
      "price": 16.75,
      "quantity": 2,
      "total": 33.50
    }
  ],
  "subtotal": 33.50,
  "tax": 2.76,
  "total": 36.26,
  "specialInstructions": "Extra crispy crust please"
}
```

```bash
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{"tableNumber":4,"items":[{"foodId":"food_2","name":"Artisan Margherita Pizza","price":16.75,"quantity":1,"total":16.75}],"total":16.75}'
```

### 4. View Submitted Orders (Kitchen View)
- **URL**: `GET /orders`

```bash
curl http://localhost:3000/orders
```
