const { Sequelize } = require('sequelize');

const sequelize = new Sequelize('postgres://username:password@localhost:5432/wheelhours_db', {
  dialect: 'postgres',
});

module.exports = sequelize;
