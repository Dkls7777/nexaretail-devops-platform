const express = require('express');
const router = express.Router();

const orders = [
  { id: 'CMD-001', merchant: 'Boutique Paris', amount: 1250.00, status: 'delivered', items: 3 },
  { id: 'CMD-002', merchant: 'Shop Lyon', amount: 890.50, status: 'processing', items: 1 },
  { id: 'CMD-003', merchant: 'Store Bordeaux', amount: 3400.00, status: 'pending', items: 7 },
  { id: 'CMD-004', merchant: 'Boutique Paris', amount: 560.00, status: 'delivered', items: 2 },
  { id: 'CMD-005', merchant: 'E-shop Nantes', amount: 2100.75, status: 'processing', items: 4 }
];

router.get('/', (req, res) => {
  res.json({ total: orders.length, orders });
});

router.get('/stats/summary', (req, res) => {
  const totalRevenue = orders.reduce((sum, o) => sum + o.amount, 0);
  const byStatus = orders.reduce((acc, o) => {
    acc[o.status] = (acc[o.status] || 0) + 1;
    return acc;
  }, {});
  res.json({
    totalOrders: orders.length,
    totalRevenue: totalRevenue.toFixed(2),
    byStatus,
    merchants: [...new Set(orders.map(o => o.merchant))].length
  });
});

router.get('/:id', (req, res) => {
  const order = orders.find(o => o.id === req.params.id);
  if (!order) return res.status(404).json({ error: 'Commande non trouvée' });
  res.json(order);
});

module.exports = router;
