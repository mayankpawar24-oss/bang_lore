'use strict';

/**
 * src/utils/logger.js
 * Winston logger configuration.
 *  - Development: pretty-printed, colourised console output
 *  - Production: JSON lines to stdout (suitable for log aggregators)
 */

const { createLogger, format, transports } = require('winston');

const { combine, timestamp, errors, json, colorize, printf } = format;

const isProduction = process.env.NODE_ENV === 'production';

const devFormat = combine(
  colorize({ all: true }),
  timestamp({ format: 'HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp: ts, stack, ...meta }) => {
    let log = `${ts} [${level}] ${message}`;
    if (stack) log += `\n${stack}`;
    const extras = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    return log + extras;
  })
);

const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  json()
);

const logger = createLogger({
  level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
  format: isProduction ? prodFormat : devFormat,
  transports: [new transports.Console()],
  exitOnError: false,
});

module.exports = logger;
