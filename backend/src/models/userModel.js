import { Sequelize } from "sequelize";
import { DataTypes } from "sequelize";
import sequelize from "../config/db.config.js";

//const { DataTypes } = require("sequelize");
//const sequelize = require("../config/db.config");

const User = sequelize.define("User", {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },

  code: {
    type: DataTypes.STRING(30),
    allowNull: false,
    unique: true,
    //comment: "Generado automáticamente. Ej: D-FE34-03-1-2025"
  },

  name: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },

  last_name: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },

  email: {
    type: DataTypes.STRING(150),
    allowNull: false,
    unique: true,
    validate: {
      isEmail: true,
    },
  },

  birth_date: {
    type: DataTypes.DATEONLY,
    allowNull: false,
    validate: {
      isDate: true,
      isAfter: "1900-01-01", 
    }
  },

  country: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: "country_codes",
      key: "id",
    },
  },

  phone: {
    type: DataTypes.STRING(20),
    allowNull: false,
    unique: true,
    validate: {
      is: /^[0-9+()-]+$/i,
    },
  },

  weight: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },

  height: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },

  gender_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: "event_categories",
      key: "id",
    },
    onDelete: "SET NULL",
  },

  size_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: "event_categories",
      key: "id",
    },
  },

  role_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 9, // ID of 'User' in event_categories
    references: {
      model: "event_categories",
      key: "id",
    },
  },

  username: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true,
  },

  password: {
    type: DataTypes.STRING(255),
    allowNull: false,
  },

  diver_type_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 11, // ID of 'Diver' in event_categories
    references: {
      model: "event_categories",
      key: "id",
    },
  },

  certifying_entity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: "certifying_entities",
      key: "id",
    },
  },

  diving_level: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: "diver_levels",
      key: "id",
    },
  },

  instructor_level: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: {
      model: "instructor_levels",
      key: "id",
    },
  },

  federation_license: {
    type: DataTypes.STRING(20),
    allowNull: false,
    unique: true,
  },

  insurance: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },

  insurance_policy: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true,
  },

  registration_date: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },

  is_active: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },

  total_dives: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },

  credits: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  }
}, {
  tableName: "users",
  timestamps: false,
});

module.exports = User;
export default User;
export { User };