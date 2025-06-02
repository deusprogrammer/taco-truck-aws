import configData from './react-config.json';

const awsConfig = {
    Auth: {
        Cognito: {
            region: 'us-east-1',
            userPoolId: configData.user_pool_id,
            userPoolClientId: configData.user_pool_client_id,
            loginWith: {
                oauth: {
                    domain: configData.cognito_domain_url,
                    scope: ["email", "openid", "profile"],
                    redirectSignIn: "http://localhost:3000/callback", // Replace with your app's URL
                    redirectSignOut: "http://localhost:3000/logout", // Replace with your app's URL
                    responseType: "code", // Use "code" for Authorization Code Grant
                },
            },
        },
    },
    API: {
        REST: {
            "taco-truck-api": {
                endpoint: `https://${configData.api_gateway_id}.execute-api.us-east-1.amazonaws.com/dev`,
                region: 'us-east-1',
            }
        }
    },
};

export default awsConfig;