/* eslint-disable @typescript-eslint/no-require-imports */
const express = require('express');
const cors = require('cors');
const config = require('./broker/config');
const { registerRoutes } = require('./broker/routes');

const app = express();

process.on('uncaughtException', (err) => console.error('!!! Uncaught Exception:', err));
process.on('unhandledRejection', (reason, p) => console.error('!!! Unhandled Rejection at:', p, 'reason:', reason));

app.use(cors());
app.use(express.json());

registerRoutes(app);

app.listen(config.port, config.host, () => {
    console.log(`WindowsDoctor Broker Running at http://${config.host}:${config.port}`);
});
