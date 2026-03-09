const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

exports.helloTest = onRequest((req, res) => {
  logger.info("helloTest ejecutada");
  res.send("Hola, Cloud Functions funciona 🚀");
});
