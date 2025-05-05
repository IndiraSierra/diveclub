const express = require('express');
const router = express.Router();
const Item = require('../../models/item.model');

// 🔹 Create new item
router.post('/', async (req, res) => {
  try {
    const { name, description } = req.body;
    const newItem = await Item.create({ name, description });
    res.status(201).json({ message: 'Item sussesfuly created', item: newItem });
  } catch (err) {
    console.error('Error creating item:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// 🔹 Getting all items
router.get('/', async (req, res) => {
  try {
    const items = await Item.findAll();
    res.status(200).json(items);
  } catch (err) {
    console.error('Error getting item:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// 🔹 Get item by ID
router.get('/:id', async (req, res) => {
  try {
    const item = await Item.findByPk(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }
    res.status(200).json(item);
  } catch (err) {
    console.error('Error getting item:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// 🔹 Update item
router.put('/:id', async (req, res) => {
  try {
    const { name, description } = req.body;
    const item = await Item.findByPk(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }
    await item.update({ name, description });
    res.status(200).json({ message: 'Item sussesfuly updated', item });
  } catch (err) {
    console.error('Error updating item:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// 🔹 Delete item
router.delete('/:id', async (req, res) => {
  try {
    const item = await Item.findByPk(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }
    await item.destroy();
    res.status(200).json({ message: 'Item sussesfuly deleted' });
  } catch (err) {
    console.error('Error deleting item:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

module.exports = router;
