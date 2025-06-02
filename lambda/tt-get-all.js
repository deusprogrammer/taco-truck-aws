const AWS = require("aws-sdk");
const { getSecurityDetails } = require("./helpers/security.js");

// Initialize DynamoDB DocumentClient
const dynamodb = new AWS.DynamoDB.DocumentClient();

// DynamoDB table name (passed via environment variable)
const TABLE_NAME = process.env.DYNAMODB_TABLE;

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

    const items = await dynamodb
      .scan({
        TableName: TABLE_NAME
      })
      .promise();

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        message: "Payload successfully retrieved",
        items: items?.Items || [],
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