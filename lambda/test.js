const Ajv = require("ajv");
const fs = require("fs");
const path = require("path");

const {schema} = require("./schemas/panel.schema.js");

const filePath = path.join(__dirname, "example.json");
const fileContent = fs.readFileSync(filePath, "utf-8");
const jsonObject = JSON.parse(fileContent);

const ajv = new Ajv({ allErrors: true, strict: false });
const validate = ajv.compile(schema);
const valid = validate(jsonObject);
if (!valid) {
  console.log("Validation errors:", validate.errors);
}
else {
  console.log("JSON is valid");
}