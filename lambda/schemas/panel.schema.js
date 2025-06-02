module.exports.schema = {
  type: "array",
  items: { $ref: "#/definitions/part" }, // Reference the "part" definition
  definitions: {
    part: {
      type: "object",
      required: ["id", "type", "position", "origin", "anchor", "dimensions", "name"],
      properties: {
        id: { type: "string" },
        type: { type: "string" },
        position: {
          type: "array",
          items: { type: "number" },
          minItems: 2,
          maxItems: 2,
        },
        origin: {
          type: "array",
          items: { type: "number" },
          minItems: 2,
          maxItems: 2,
        },
        anchor: {
          type: "array",
          items: { type: "number" },
          minItems: 2,
          maxItems: 2,
        },
        dimensions: {
          type: "array",
          items: { type: "number" },
          minItems: 2,
          maxItems: 2,
        },
        name: { type: "string" },
        partId: { type: "string" },
        layout: {
          type: "object",
          required: ["panelDimensions", "units", "name"],
          properties: {
            panelDimensions: {
              type: "array",
              items: { type: "number" },
              minItems: 2,
              maxItems: 2,
            },
            units: { type: "string" },
            name: { type: "string" },
            parts: {
              type: "array",
              items: { $ref: "#/definitions/part" }, // Recursive reference to the "panel" definition
            },
          },
        },
      },
    },
  },
};