const { Model, DataTypes } = require('sequelize');
const sequelize = require('../config/db');

class TimeLog extends Model {}

TimeLog.init({
  taskId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  startTime: {
    type: DataTypes.DATE,
    allowNull: false,
  },
  endTime: {
    type: DataTypes.DATE,
    allowNull: true,
  },
}, { sequelize, modelName: 'time_log' });

module.exports = TimeLog;
