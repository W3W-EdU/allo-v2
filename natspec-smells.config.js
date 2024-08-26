/**
 * List of supported options: https://github.com/defi-wonderland/natspec-smells?tab=readme-ov-file#options
 */

/** @type {import('@defi-wonderland/natspec-smells').Config} */
module.exports = {
  include: 'contracts/(extensions|core|strategies)/**/*.sol',
  exclude: 'contracts/strategies/_poc/**/*.sol',
  enforceInheritdoc: false,
};