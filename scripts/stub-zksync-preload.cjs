const Module = require("module");
const path = require("path");
const stub = path.join(__dirname, "../vendor/zksync-ethers-stub/index.js");
const orig = Module._resolveFilename;
Module._resolveFilename = function (request, parent, isMain, options) {
  if (request === "zksync-ethers") return stub;
  return orig.call(this, request, parent, isMain, options);
};
