
require('dotenv').config();
const transact = require("./scripts/transact.js");
const PrivateKeyProvider = require("truffle-privatekey-provider");
const account = process.env.address;
const password = process.env.password;
const privKey = transact.getPrivateKey(account, "./", password).then(function(privateKey){return privateKey;});

module.exports = {
  networks: {
    ganache: {
      provider: () => new PrivateKeyProvider(privKey, "https://127.0.0.1:7545"),
      host:"https://127.0.0.1",
      port:"7545",
      network_id: "*" // matching any id
    }
  }
};
