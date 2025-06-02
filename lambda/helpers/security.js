module.exports = {
    getSecurityDetails: (event) => {
        // Initialize variables for authentication and role
        let isAuthenticated = false;
        let isAdmin = false;

        // Check if the request context contains authorizer claims
        const claims = event.requestContext?.authorizer?.claims;

        if (claims) {
            // User is authenticated
            isAuthenticated = true;

            // Extract user groups from the claims
            const userGroups = claims["cognito:groups"] || []; // Groups the user belongs to

            // Determine the user's role
            isAdmin = userGroups.includes("Admin");
        }

        return {
            isAuthenticated,
            isAdmin,
        };
    }
}