

  /*birth_date: {
    type: DataTypes.DATEONLY,
    allowNull: false,
    validate: {
      isDate: true,
      isBefore: new Date().toISOString().split("T")[0], // before today
      isAfter: new Date("1900-01-01").toISOString().split("T")[0], // after 1900
      is: {
        args: /^\d{4}-\d{2}-\d{2}$/,
        msg: "Invalid date format. Use YYYY-MM-DD.",
      },
      isValidDate(value) {
        const date = new Date(value);
        if (isNaN(date.getTime())) {
          throw new Error("Invalid date");
        }
        const today = new Date();
        if (date >= today) {
          throw new Error("Birth date must be in the past");
        }
      },
      isValidDateRange(value) {
        const date = new Date(value);
        const minDate = new Date("1900-01-01");
        if (date < minDate) {
          throw new Error("Birth date must be after 1900-01-01");
        }
      },
      isValidDateFormat(value) {
        const regex = /^\d{4}-\d{2}-\d{2}$/;
        if (!regex.test(value)) {
          throw new Error("Invalid date format. Use YYYY-MM-DD.");
        }
      },
    },
  },

const { User } = require('../models/user.model');
const bcrypt = require('bcrypt');
const { Op } = require('sequelize');
const { generateCode } = require('../utils/code.utils'); // función para generar código único
const { hashPassword } = require('../utils/password.utils');

// 🧠 User register function
const register = async (req, res) => {
  try {
    const {
      name,
      last_name,
      email,
      birth_date,
      phone,
      gender_id,
      weight,
      height,
      size_id,
      role_id,
      username,
      password,
      diver_type_id,
      certifying_entity,
      diving_level,
      instructor_level,
      federation_license,
      insurance,
      insurance_policy,
    } = req.body;

    // 1️⃣ Basic validations. Fields and types
    if (!name || !last_name || !email || !birth_date || !phone || !username || !password ||
        !gender_id || !weight || !height || !size_id || !role_id || !diver_type_id ||
        !certifying_entity || !diving_level || !federation_license || !insurance_policy) {
      return res.status(400).json({ message: 'All required fields must be filled.' });
    }

    // 2️⃣ Dates validation
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(birth_date)) {
      return res.status(400).json({ message: 'Formato de fecha inválido. Use YYYY-MM-DD.' });
    }
    const birthDateObj = new Date(birth_date);
    if (isNaN(birthDateObj.getTime()) || birthDateObj >= new Date() || birthDateObj < new Date('1900-01-01')) {
      return res.status(400).json({ message: 'Fecha de nacimiento fuera de rango válido.' });
    }

    // 3️⃣ singularity validation
    const existingUser = await User.findOne({
      where: {
        [Op.or]: [
          { email },
          { username },
          { phone },
          { federation_license },
          { insurance_policy },
        ]
      }
    });
    if (existingUser) {
      return res.status(409).json({ message: 'Ya existe un usuario con alguno de los datos únicos ingresados.' });
    }

    // 4️⃣ password hashing
    if (password.length < 8) {
        return res.status(400).json({ message: 'Password must be at least 8 characters.' });
        }
    const hashedPassword = await hashPassword(password);

    // 5️⃣ wait for code generator(ej. D-FE34-03-1-2025)
    const code = await generateCode(certifying_entity, diving_level);

    // 6️⃣ New User INSERT
    const newUser = await User.create({
      name,
      last_name,
      email,
      birth_date,
      phone,
      gender_id,
      weight,
      height,
      size_id,
      role_id,
      username,
      password: hashedPassword,
      diver_type_id,
      certifying_entity,
      diving_level,
      instructor_level: instructor_level || null,
      federation_license,
      insurance: insurance === true || insurance === 'true' ? true : false,
      insurance_policy: insurance === false ? 'BLOCKED' : insurance_policy, 
      registration_date: new Date(),
      is_active: true,
      credits: 0,
      total_dives: 0,
      code
    });

    return res.status(201).json({
      message: 'User successfully registered',
      user: {
        id: newUser.id,
        username: newUser.username,
        email: newUser.email,
        code: newUser.code,
        role: role_id,
      }
    });
  } catch (error) {
    console.error('Error registering user:', error);
    return res.status(500).json({ message: 'Iternal Server Error' });
  }
};

module.exports = {
  register
};
*/
// controllers/user.controller.js

const { Op } = require("sequelize");
const bcrypt = require("../utils/password.utils");
const jwtUtils = require("../utils/jwt.utils");
const User = require("../models/user.model");
const EventCategory = require("../models/eventCategory.model"); // Para validaciones cruzadas

// Registro de usuario
const registerUser = async (req, res) => {
  try {
    const {
      name,
      last_name,
      email,
      birth_date,
      country,
      phone,
      gender_id,
      weight,
      height,
      size_id,
      username,
      password,
      diver_type_id,
      certifying_entity,
      diving_level,
      instructor_level,
      federation_license,
      insurance,
      insurance_policy
    } = req.body;

    // Validación cruzada: ¿ya existe ese usuario por email/username/license/phone?
    const userExists = await User.findOne({
      where: {
        [Op.or]: [
          { email },
          { username },
          { phone },
          { federation_license },
          { insurance_policy },
        ],
      },
    });

    if (userExists) {
      return res.status(409).json({ message: "Usuario ya registrado con alguno de los datos proporcionados." });
    }

    // Encriptamos la contraseña
    const hashedPassword = await bcrypt.hashPassword(password);

    // Generamos código único tipo "D-FE34-03-1-2025"
    const currentYear = new Date().getFullYear();
    const code = `D-${username.substring(0, 4).toUpperCase()}-${Math.floor(Math.random() * 99)}-${Math.floor(Math.random() * 9)}-${currentYear}`;

    // Creamos el nuevo usuario
    const newUser = await User.create({
      code,
      name,
      last_name,
      email,
      birth_date,
      country,
      phone,
      gender_id,
      weight,
      height,
      size_id,
      role_id: 9, // 'User' por defecto
      username,
      password: hashedPassword,
      diver_type_id,
      certifying_entity,
      diving_level,
      instructor_level: instructor_level || null,
      federation_license,
      insurance,
      insurance_policy,
    });

    res.status(201).json({ message: "Usuario registrado correctamente", userId: newUser.id });

  } catch (error) {
    console.error("Error en registerUser:", error);
    res.status(500).json({ message: "Error del servidor al registrar usuario" });
  }
};

// Login del usuario
const loginUser = async (req, res) => {
  try {
    const { emailOrUsername, password } = req.body;

    const user = await User.findOne({
      where: {
        [Op.or]: [{ email: emailOrUsername }, { username: emailOrUsername }],
      },
    });

    if (!user) {
      return res.status(401).json({ message: "Credenciales inválidas." });
    }

    const isPasswordValid = await bcrypt.comparePassword(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ message: "Credenciales inválidas." });
    }

    const token = jwtUtils.generateToken({
      id: user.id,
      role_id: user.role_id,
      username: user.username,
    });

    res.status(200).json({ token, user: { id: user.id, username: user.username, role_id: user.role_id } });

  } catch (error) {
    console.error("Error en loginUser:", error);
    res.status(500).json({ message: "Error del servidor al iniciar sesión" });
  }
};

// Obtener perfil del usuario autenticado
const getUserProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const user = await User.findByPk(userId, {
      attributes: { exclude: ["password"] },
    });

    if (!user) {
      return res.status(404).json({ message: "Usuario no encontrado." });
    }

    res.status(200).json(user);

  } catch (error) {
    console.error("Error en getUserProfile:", error);
    res.status(500).json({ message: "Error al obtener perfil." });
  }
};

module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
};

