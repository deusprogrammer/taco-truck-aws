const AWS = require("aws-sdk");
const Ajv = require("ajv");
const { schema } = require("./schemas/panel.schema.js");
const { getSecurityDetails } = require("./helpers/security");

// Initialize DynamoDB DocumentClient
const dynamodb = new AWS.DynamoDB.DocumentClient();

// DynamoDB table name (passed via environment variable)
const TABLE_NAME = process.env.DYNAMODB_TABLE;

// Initialize JSON schema validator
const ajv = new Ajv();

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type,Authorization"
}

exports.handler = async (event) => {
  try {
    const { isAuthenticated, isAdmin } = getSecurityDetails(event);
    
    if (!isAuthenticated) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({
          message: "Unauthorized",
        }),
      };
    }

    // Parse the request body
    const body = JSON.parse(event.body);

    // Validate the request body against the schema
    const validate = ajv.compile(schema);
    const valid = validate(body);

    if (!valid) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          message: "Invalid request body",
          errors: validate.errors,
        }),
      };
    }

    // Store the validated payload in DynamoDB
    const item = {
      id: `batch-${Date.now()}`, // Unique ID for the batch
      owner: 'user', // Replace with actual owner ID if available
      tags: ['tag1', 'tag2'], // Replace with actual tags if available
      payload: body, // Store the entire validated payload
    };

    await dynamodb
      .put({
        TableName: TABLE_NAME,
        Item: item,
      })
      .promise();

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        message: "Payload successfully stored",
        item,
      }),
    };
  } catch (error) {
    console.error("Error:", error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        message: "Internal server error",
        error: error.message,
      }),
    };
  }
};