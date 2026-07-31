const { Model, DataTypes } = require('sequelize');
const sequelize = require('../config/db');

class Task extends Model {}

Task.init({
  title: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  description: {
    type: DataTypes.TEXT,
  },
  projectId: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
}, { sequelize, modelName: 'task' });

module.exports = Task;
